const String mesConsultationsQuery = r'''
  query MesConsultations($first: Int, $page: Int) {
    mesConsultations(first: $first, page: $page) {
      data {
        id
        type_consultation
        statut
        cout_consultation
        symptomes
        created_at
        medecin {
          id
          nom
          prenom
          specialite
        }
        teleconsultation {
          agora_channel
        }
      }
      paginatorInfo {
        hasMorePages
        currentPage
        total
      }
    }
  }
''';

const String pharmaciesProchesQuery = r'''
  query PharmaciesProches($latitude: Float!, $longitude: Float!, $rayon: Float) {
    pharmaciesProches(latitude: $latitude, longitude: $longitude, rayon: $rayon) {
      id
      nom_pharmacie
      adresse
      telephone
      distance
      livraison_disponible
      est_active
      heures_ouverture
    }
  }
''';

const String demanderConsultationMutation = r'''
  mutation DemanderConsultation($input: DemanderConsultationInput!) {
    demanderConsultation(input: $input) {
      id
      type_consultation
      statut
      cout_consultation
      symptomes
      medecin {
        id
        nom
        prenom
        specialite
      }
    }
  }
''';

const String demarrerTeleConsultationMutation = r'''
  mutation DemarrerTeleConsultation($consultation_id: ID!) {
    demarrerTeleConsultation(consultation_id: $consultation_id) {
      agora_channel
      agora_token
      agora_app_id
    }
  }
''';

const String consultationDetailQuery = r'''
  query ConsultationDetail($id: ID!) {
    consultation(id: $id) {
      id
      type_consultation
      statut
      cout_consultation
      symptomes
      diagnostic
      recommandations
      notes_consultation
      date_consultation
      duree_minutes
      note_patient
      created_at
      medecin {
        id
        nom
        prenom
        specialite
        hopital_rattachement
        tarif_consultation
        note_moyenne
        est_certifie
      }
      patient {
        id
        nom
        prenom
        age
        genre
        groupe_sanguin
        allergies
      }
      prescriptions {
        id
        instructions
        validite_jours
        created_at
        medicaments_prescrits {
          id
          quantite
          posologie
          duree_traitement
          instructions_speciales
          medicament {
            id
            nom_commercial
            dosage
          }
        }
      }
      teleconsultation {
        agora_channel
        duree_consultation
      }
    }
  }
''';

const String medecinsPaginateQuery = r'''
  query Medecins($specialite: String, $first: Int!, $page: Int) {
    medecins(specialite: $specialite, first: $first, page: $page) {
      data {
        id
        nom
        prenom
        specialite
        tarif_consultation
        note_moyenne
        est_certifie
        disponible_maintenant
        photo
      }
      paginatorInfo {
        hasMorePages
        currentPage
        total
      }
    }
  }
''';

const String pharmaciesAvecStockQuery = r'''
  query PharmaciesAvecStock($latitude: Float!, $longitude: Float!, $rayon: Float) {
    pharmaciesProches(latitude: $latitude, longitude: $longitude, rayon: $rayon) {
      id
      nom_pharmacie
      adresse
      distance
      livraison_disponible
      stocks {
        quantite_disponible
        prix_vente
        medicament {
          id
        }
      }
    }
  }
''';

const String commanderMedicamentsMutation = r'''
  mutation CommanderMedicaments($input: CommandeInput!) {
    commanderMedicaments(input: $input) {
      id
      numero_commande
      montant_total
      frais_livraison
    }
  }
''';

const String mesCommandesQuery = r'''
  query MesCommandes($first: Int, $page: Int) {
    mesCommandes(first: $first, page: $page) {
      data {
        id
        numero_commande
        statut
        type_livraison
        adresse_livraison
        montant_total
        frais_livraison
        created_at
        pharmacie {
          nom_pharmacie
          adresse
          telephone
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
