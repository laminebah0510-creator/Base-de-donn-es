# Automatisation de la Gestion des Offres Commerciales

## Présentation

Ce projet a été réalisé dans le cadre du module d'Exploration de Données. Il vise à automatiser la gestion des offres commerciales d'une chaîne de magasins à partir de relevés de prix quotidiens stockés dans des fichiers CSV.

Chaque fichier représente une journée d'observation et contient les prix relevés pour différents produits dans plusieurs magasins. Le système doit maintenir à jour une table `Offer` représentant les offres actives tout en assurant leur création, leur mise à jour ou leur clôture selon les données observées.

---

## Objectifs du projet

Les objectifs principaux sont les suivants :

* Importer automatiquement les relevés de prix depuis des fichiers CSV.
* Contrôler la qualité des données et supprimer les anomalies.
* Mettre à jour la table `Offer` en fonction des relevés.
* Identifier et clôturer les offres devenues inactives.
* Mettre en place un système de journalisation (logs).
* Vérifier l'intégrité et la cohérence des données après traitement.

---

## Fonctionnalités

### Importation des données

* Lecture des fichiers CSV.
* Contrôle des données importées.
* Détection des prix aberrants ou nuls.
* Intégration progressive des fichiers.

### Gestion des offres

* Création automatique des nouvelles offres.
* Mise à jour des offres existantes.
* Actualisation de la date de vérification (`VerifiedDate`).
* Fermeture des offres non observées dans les relevés.

### Journalisation

* Enregistrement des différentes étapes du traitement.
* Suivi du nombre d'offres créées, mises à jour et clôturées.
* Historisation des opérations réalisées.

### Vérification des données

* Contrôle de cohérence après chaque import.
* Validation des mises à jour effectuées.
* Vérification du statut des offres actives et expirées.

---

## Structure des données

Le projet s'appuie sur les tables suivantes :

### Store

Contient les informations relatives aux magasins.

### EANItem

Associe chaque code EAN à un article et à sa description.

### Offer

Contient l'ensemble des offres commerciales avec :

* Produit concerné ;
* Magasin ;
* Prix ;
* Date de création ;
* Date de vérification ;
* Date de clôture.

Une offre active possède une `ClosingDate` égale à :

```sql
9999-12-31
```

---

## Fichiers sources

Les relevés de prix sont fournis sous la forme des fichiers suivants :

* DATA20241104.csv
* DATA20241111.csv
* DATA20241118.csv
* DATA20241125.csv
* DATA20241202.csv

Chaque fichier contient :

* Le code EAN du produit ;
* Le StoreNumberID ;
* Le prix recommandé ;
* Le prix appliqué en magasin.

---

## Technologies utilisées

* SQL
* Fichiers CSV
* Système de gestion de base de données relationnelle
* Scripts d'automatisation

---

## Méthodologie

1. Importation du fichier CSV.
2. Nettoyage et validation des données.
3. Détection des nouvelles offres.
4. Mise à jour des offres existantes.
5. Clôture des offres inactives.
6. Enregistrement des opérations dans la table de logs.
7. Vérification de la cohérence des données.

---

## Compétences développées

* Manipulation de données.
* SQL avancé.
* Automatisation de traitements.
* Gestion des données commerciales.
* Contrôle qualité des données.
* Journalisation et suivi des processus.
* Modélisation relationnelle.

---

## Perspectives d'amélioration

* Automatisation complète du traitement de plusieurs fichiers.
* Génération automatique de rapports.
* Optimisation des performances SQL.
* Mise en place d'alertes en cas d'anomalies.
* Création d'une interface de suivi des traitements.

---

## Auteur

Bah Mohamed Lamine

---

## Licence

Projet réalisé à des fins pédagogiques et académiques.
