const String mesConsultationsQuery = r'''
  query MesConsultations($first: Int, $page: Int) {
    mesConsultations(first: $first, page: $page) {
      data {
        id
        type
        statut
        cout
        symptomes
        created_at
        medecin {
          id
          specialite
          user {
            nom
            prenom
          }
        }
        teleconsultation {
          agora_channel
          agora_token
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

const String mesRendezVousQuery = r'''
  query MesRendezVous($first: Int) {
    mesRendezVous(first: $first) {
      data {
        id
        date_rendez_vous
        statut
        type
        lieu
        medecin {
          user { nom prenom }
          specialite
        }
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
  mutation DemanderConsultation($input: ConsultationInput!) {
    demanderConsultation(input: $input) {
      id
      type
      statut
      cout
      symptomes
      medecin {
        id
        user { nom prenom }
        specialite
      }
    }
  }
''';

const String demarrerTeleConsultationMutation = r'''
  mutation DemarrerTeleConsultation($consultationId: ID!) {
    demarrerTeleConsultation(consultationId: $consultationId) {
      agora_channel
      agora_token
      agora_uid
    }
  }
''';

const String medecinsPaginateQuery = r'''
  query Medecins($specialite: String, $first: Int, $page: Int) {
    medecins(specialite: $specialite, first: $first, page: $page) {
      data {
        id
        specialite
        tarif_consultation
        note_moyenne
        est_certifie
        disponible_maintenant
        user {
          nom
          prenom
          photo
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
