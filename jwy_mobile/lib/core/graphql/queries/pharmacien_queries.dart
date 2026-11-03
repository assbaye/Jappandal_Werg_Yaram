const String maPharmacieQuery = r'''
  query MaPharmacie {
    maPharmacie {
      id
      nom_pharmacie
      adresse
      telephone
      livraison_disponible
      est_de_garde
      de_garde_jusqu_au
      statut_ouverture
    }
  }
''';

const String declarerGardeMutation = r'''
  mutation DeclarerGarde($jusqu_au: DateTime) {
    declarerGarde(jusqu_au: $jusqu_au) {
      id
      est_de_garde
      statut_ouverture
    }
  }
''';

const String monStockQuery = r'''
  query MonStock($first: Int, $page: Int) {
    monStock(first: $first, page: $page) {
      data {
        id
        quantite_disponible
        quantite_minimale
        prix_vente
        date_expiration
        is_stock_faible
        medicament {
          id
          nom_commercial
          principe_actif
          dosage
          forme
          necessite_ordonnance
        }
      }
    }
  }
''';

const String updateStockMutation = r'''
  mutation UpdateStock($medicament_id: ID!, $quantite_disponible: Int!, $prix_vente: Float, $quantite_minimale: Int) {
    updateStock(
      medicament_id: $medicament_id
      quantite_disponible: $quantite_disponible
      prix_vente: $prix_vente
      quantite_minimale: $quantite_minimale
    ) {
      id
      quantite_disponible
      prix_vente
      is_stock_faible
    }
  }
''';

const String commandesPharmacieQuery = r'''
  query CommandesPharmacie($first: Int, $page: Int, $statut: StatutCommande) {
    commandesPharmacie(first: $first, page: $page, statut: $statut) {
      data {
        id
        numero_commande
        statut
        type_livraison
        adresse_livraison
        montant_total
        frais_livraison
        created_at
        prescription {
          id
        }
        patient {
          id
          nom
          prenom
        }
        lignes {
          quantite
          prix_unitaire
          medicament {
            nom_commercial
            dosage
          }
        }
      }
    }
  }
''';

const String updateStatutCommandeMutation = r'''
  mutation UpdateStatutCommande($id: ID!, $statut: StatutCommande!) {
    updateStatutCommande(id: $id, statut: $statut) {
      id
      statut
    }
  }
''';
