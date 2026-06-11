 --#################---RESOLUTION DU PROJET---###################


--1 Créer un processus automatisé pour l’importation des données :


 
DROP TABLE IF EXISTS ventes1;
 CREATE TABLE ventes1 (
    EAN VARCHAR(13),
    StoreNumberID INT,
    RecommendedPrice DECIMAL(10,2),
    AppliedPrice DECIMAL(10,2)
)
 
TRUNCATE TABLE ventes1;                        -- si l'analyse est journalière
DECLARE @fichier_vente NVARCHAR(50) = 'DATA20241118';  
DECLARE @Date_vente DATE = '2024-12-02';         -- date du fichier
DECLARE @emplacement NVARCHAR(260) = 'C:\Users\HP\Documents\SQL\Projet\';
DECLARE @sql NVARCHAR(MAX) =

N'BULK INSERT ventes1

  FROM ''' + @emplacement + @fichier_vente + N'.csv''
  WITH (
      FIRSTROW = 2,
      FIELDTERMINATOR = '';'',
      ROWTERMINATOR = ''0x0d0a'',   -- Windows (CRLF)
      TABLOCK

  );';
 
EXEC sys.sp_executesql @sql;
 
-- Verification

SELECT COUNT(*) AS ImportedRows FROM dbo.ventes1;
SELECT  * FROM dbo.ventes1;

-- Suppression des prix abberants

DELETE
FROM ventes1
WHERE RecommendedPrice = 0
   OR AppliedPrice = 0
   OR RecommendedPrice > 1000
   OR AppliedPrice > 1000;

SELECT @@ROWCOUNT AS Lignes_Rejetees;


--2 – Mettre à jour la table Offer : 

    --Créer de nouvelles offres si elles apparaissent dans les relevés et qu’elles n’existent pas encore dans la table Offer.


DECLARE @Date_vente DATE = '2024-11-11';
 INSERT INTO Offer (
    NumberID,
    StoreNumberID,
    StoreDescription,
    EAN,
    ItemDescription,
    PeriodStart,
    PeriodEnd,
    Price,
    VerifiedDate,
    StockShortageDate
)

SELECT
 ROW_NUMBER() OVER (ORDER BY v.EAN, v.StoreNumberID) + ISNULL((SELECT MAX(NumberID)
 FROM Offer), 0) AS NumberID,
 v.StoreNumberID,
 s.description AS StoreDescription,
 CAST(v.EAN AS bigint) AS EAN,
 ei.ItemDescription AS ItemDescription,
 CAST(@FileDate AS datetime) AS PeriodStart,
 DATETIMEFROMPARTS(9999,12,31,0,0,0,0) AS PeriodEnd,
 CAST(v.AppliedPrice AS money) AS Price,
 CAST(@FileDate AS datetime) AS VerifiedDate,
   NULL AS StockShortageDate
FROM ventes1 v
JOIN Store s ON s.numberid = v.StoreNumberID
LEFT JOIN EANItem ei ON ei.ean = CAST(v.EAN AS bigint)
WHERE NOT EXISTS (
   SELECT 1
   FROM Offer o
   WHERE o.EAN = CAST(v.EAN AS bigint)
        AND o.StoreNumberID = v.StoreNumberID
        AND o.PeriodEnd = DATETIMEFROMPARTS(9999,12,31,0,0,0,0)
);

-- Mettre à jour les offres existantes (màj de la VerifiedDate)

DECLARE  @Date_vente DATE = '2024-11-11';
 
 
UPDATE o
SET o.VerifiedDate = CAST(@Date_vente AS datetime)
FROM Offer o
JOIN ventes1 v
  ON o.StoreNumberID = v.StoreNumberID
AND o.EAN = TRY_CAST(v.EAN AS bigint)
WHERE o.PeriodEnd = DATETIMEFROMPARTS(9999,12,31,0,0,0,0);
 
 
 ---- Nombre d'offres mise à jour --
 
SELECT @@ROWCOUNT AS Nb_offres_à_jour; -- nombres de lignes m.a.j dans la requete precedente

--Clôturer les offres qui ne sont plus actives en fonction des relevés (attention plusieurs cas possibles)

 -- Cas 1 : Offres dont le prix a changé --
 
 
      -- Offres actives dont le prix est différent du relevé du jour

      DECLARE @Date_vente DATE = '2024-11-11'; 
SELECT
    o.NumberID,
    o.StoreNumberID,
    o.EAN,
    o.Price AS OldPrice,
    v.AppliedPrice AS NewPrice,
    o.PeriodStart,
    o.PeriodEnd
FROM Offer o
JOIN ventes1 v
  ON o.StoreNumberID = v.StoreNumberID
AND o.EAN = TRY_CAST(v.EAN AS bigint)
WHERE o.PeriodEnd = DATETIMEFROMPARTS(9999,12,31,0,0,0,0)
  AND o.Price IS NOT NULL
  AND o.Price <> CAST(v.AppliedPrice AS money);
 
UPDATE o

SET o.PeriodEnd = CAST(@Date_vente AS datetime)  -- fermeture à la date du fichier
FROM Offer o
JOIN ventes1 v  ON o.StoreNumberID = v.StoreNumberID
AND o.EAN = TRY_CAST(v.EAN AS bigint)

WHERE o.PeriodEnd = DATETIMEFROMPARTS(9999,12,31,0,0,0,0)  -- uniquement offres actives
  AND o.Price IS NOT NULL
  AND o.Price <> CAST(v.AppliedPrice AS money);  -- comparaison du prix
 
      
      -- Offres fermées aujourd’hui à cause d’un changement de prix

DECLARE @Date_vente DATE = '2024-11-11'; 
UPDATE o
SET o.PeriodEnd = CAST(@Date_vente AS datetime)  -- fermeture à la date du fichier
FROM Offer o
JOIN ventes1 v
    ON o.StoreNumberID = v.StoreNumberID
   AND o.EAN = TRY_CAST(v.EAN AS bigint)
WHERE o.PeriodEnd = DATETIMEFROMPARTS(9999,12,31,0,0,0,0)  -- uniquement offres actives
  AND o.Price IS NOT NULL
  AND o.Price <> CAST(v.AppliedPrice AS money);  -- prix différent → fermeture

 
         -- CAS 2 : l'offre est absente du relévé du jour --

  DECLARE @Date_vente DATE = '2024-11-11';
 
UPDATE o
SET o.PeriodEnd = CAST(@Date_vente AS datetime)
FROM Offer o
WHERE o.PeriodEnd = DATETIMEFROMPARTS(9999,12,31,0,0,0,0)  -- offres actives
  AND NOT EXISTS (
      SELECT 1
      FROM ventes1 v
      WHERE v.StoreNumberID = o.StoreNumberID
        AND TRY_CAST(v.EAN AS bigint) = o.EAN
  );
 
       ---Cas 3: Le magasin est fermé

  UPDATE o
    SET o.PeriodEnd = CAST(@FileDate AS datetime)
    FROM Offer o
    JOIN Store s ON s.numberid = o.StoreNumberID
    WHERE o.PeriodEnd = CAST('9999-12-31T00:00:00' AS datetime)
      AND s.closingdate IS NOT NULL
      AND s.closingdate <= @FileDate;
 
    SET @ClosedStoreClosed = @@ROWCOUNT;


--3- Ajouter un mécanisme de log : 

      ---Création de la table des log---


IF OBJECT_ID('ProcessLog', 'U') IS NULL
BEGIN
    CREATE TABLE ProcessLog (
        LogID INT IDENTITY(1,1) PRIMARY KEY,                     -- Identifiant auto
        LogDate DATETIME NOT NULL DEFAULT GETDATE(),             -- Date/heure exécution
 
        nom_fichier NVARCHAR(50) NOT NULL,                        -- Nom fichier (ex: DATA20241125)
        date_fichier DATE NOT NULL,                               -- Date fichier
        ligne_importé INT  NULL,                               -- Lignes importées
        ligne_rejeté INT not NULL,                                   -- Lignes rejetées au nettoyage
        nouvelle_offre INT  NULL,                                 -- Offres créées
        ofrre_m_a_j INT NOT NULL,                                 -- Offres mises à jour (VerifiedDate)
        offre_fer_c INT NOT NULL,                                 -- Offres fermées (prix changé)
        offre_fer_a INT NOT NULL,                                 -- Offres fermées (absentes)
        offre_fer_mf INT NOT NULL                                 -- Offres fermées (magasin fermé)
    )
END;


     
            ---Ajout d'un statut---

IF COL_LENGTH('ProcessLog', 'Status') IS NULL
BEGIN
    ALTER TABLE ProcessLog
    ADD Status NVARCHAR(20) NOT NULL
        CONSTRAINT DF_ProcessLog_Statut DEFAULT 'Succès';
END;
 
           ---Ajout d'un ErrorMessage ---

IF COL_LENGTH('ProcessLog', 'ErrorMessage') IS NULL
BEGIN
    ALTER TABLE ProcessLog
    ADD ErrorMessage NVARCHAR(4000) NULL;
END;
 
     ---Index : 1 seul Succès par (nom_ficher, date_fichier)---

               --Pour créer l'index unique,il fallait identifier les doublons et les supprimer

            --Idenditification des doublons---

SELECT StoreNumberID, EAN, COUNT(*) AS Nb_Doublons FROM Offer
WHERE PeriodEnd = '9999-12-31T00:00:00'
GROUP BY StoreNumberID, EAN
HAVING COUNT(*) > 1;  

            --Suppression des doublons---

DELETE FROM Offer WHERE NumberID IN (
    SELECT NumberID
    FROM (
        SELECT NumberID,
               ROW_NUMBER() OVER (PARTITION BY StoreNumberID, EAN, PeriodEnd ORDER BY NumberID) AS rn
        FROM Offer
        WHERE PeriodEnd = '9999-12-31T00:00:00'
    ) x
    WHERE rn > 1
);

            --création de l'index unique---

    IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'Unique_Offer_Active'
      AND object_id = OBJECT_ID('Offer')
)
BEGIN
    CREATE UNIQUE INDEX Unique_Offer_Active  ON Offer (StoreNumberID, EAN)
    WHERE PeriodEnd = '9999-12-31T00:00:00';
END;



---4 Développer un script qui vérifie l’exactitude des mises à jour apportés à la table Offer


          -- A) Doublons d’offres actives--

DECLARE  @Date_vente DATE = '2024-11-11';
SELECT StoreNumberID, EAN, COUNT(*) AS NbOffresActives
FROM Offer
WHERE PeriodEnd = '9999-12-31T00:00:00'
GROUP BY StoreNumberID, EAN
HAVING COUNT(*) > 1;
 

          ---B) Prix aberrants en actif (attendu : 0 ligne)---

SELECT StoreNumberID, EAN, Price, PeriodStart, PeriodEnd, VerifiedDate
FROM dbo.Offer
WHERE PeriodEnd = '9999-12-31T00:00:00'
  AND (Price IS NULL OR Price <= 0 OR Price > 1000);
 

           
       ---C) Magasin fermé mais offre active (attendu : 0 ligne)---

DECLARE  @Date_vente DATE = '2024-11-11';
SELECT o.StoreNumberID, o.EAN, s.closingdate, o.PeriodEnd
FROM dbo.Offer o
JOIN dbo.Store s
  ON s.numberid = o.StoreNumberID
WHERE o.PeriodEnd = '9999-12-31T00:00:00'
  AND s.closingdate IS NOT NULL
  AND s.closingdate <= @Date_vente;

       ----D) Offre dont le prix est différent de celui du rélevé du jour(0 offre attendue)

       DECLARE  @Date_vente DATE = '2024-11-11';
       SELECT 
    COUNT(*) AS Nb_Offres_Actives_EcartPrix
FROM Offer o
JOIN ventes1 v
    ON o.StoreNumberID = v.StoreNumberID
   AND o.EAN = TRY_CAST(v.EAN AS bigint)
WHERE o.PeriodEnd = DATETIMEFROMPARTS(9999,12,31,0,0,0,0)
  AND o.Price <> CAST(v.AppliedPrice AS money);
         DECLARE  @Date_vente DATE = '2024-11-11';
SELECT 
    COUNT(*) AS Nb_Offres_Fermes_EcartPrix
FROM Offer o
JOIN ventes1 v
    ON o.StoreNumberID = v.StoreNumberID
   AND o.EAN = TRY_CAST(v.EAN AS bigint)
WHERE CAST(o.PeriodEnd AS date) = @Date_vente
  AND o.Price <> CAST(v.AppliedPrice AS money)

       ---E) Offres fermées aujourd’hui à cause d’un changement de prix(0 offre attendue)

DECLARE  @Date_vente DATE = '2024-11-11';
SELECT 
    COUNT(*) AS Nb_Offres_Actives_EcartPrix
FROM Offer o
JOIN ventes1 v
    ON o.StoreNumberID = v.StoreNumberID
   AND o.EAN = TRY_CAST(v.EAN AS bigint)
WHERE o.PeriodEnd = DATETIMEFROMPARTS(9999,12,31,0,0,0,0)
  AND o.Price <> CAST(v.AppliedPrice AS money);
SELECT 
    COUNT(*) AS Nb_Offres_Fermes_EcartPrix
FROM Offer o
JOIN ventes1 v
    ON o.StoreNumberID = v.StoreNumberID
   AND o.EAN = TRY_CAST(v.EAN AS bigint)
WHERE CAST(o.PeriodEnd AS date) = @Date_vente
  AND o.Price <> CAST(v.AppliedPrice AS money);

        ---F) l'offre est absente du relévé du jour

DECLARE  @Date_vente DATE = '2024-11-11';
SELECT
    COUNT(*) AS Nb_Actives_AbsentesReleve
FROM Offer o
WHERE o.PeriodEnd = DATETIMEFROMPARTS(9999,12,31,0,0,0,0)
  AND NOT EXISTS (
      SELECT 1
      FROM ventes1 v
      WHERE v.StoreNumberID = o.StoreNumberID
        AND TRY_CAST(v.EAN AS bigint) = o.EAN
  );
