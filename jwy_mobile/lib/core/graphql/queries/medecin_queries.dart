const String mesConsultationsMedecinQuery = r'''
  query MesConsultationsMedecin($first: Int, $page: Int, $statut: StatutConsultation) {
    mesConsultations(first: $first, page: $page, statut: $statut) {
      data {
        id
        type_consultation
        statut
        cout_consultation
        symptomes
        created_at
        patient {
          id
          nom
          prenom
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

const String toggleDisponibiliteMutation = r'''
  mutation ToggleDisponibilite {
    toggleDisponibilite {
      id
      disponible_maintenant
    }
  }
''';

const String medecinInfoQuery = r'''
  query MedecinInfo {
    me {
      medecin {
        id
        nom
        prenom
        specialite
        disponible_maintenant
        note_moyenne
        nombre_consultations
        tarif_consultation
      }
    }
  }
''';

const String repondreConsultationMutation = r'''
  mutation RepondreConsultation($consultation_id: ID!, $accepter: Boolean!, $motif: String) {
    repondreConsultation(consultation_id: $consultation_id, accepter: $accepter, motif: $motif) {
      id
      statut
    }
  }
''';

const String terminerConsultationMutation = r'''
  mutation TerminerConsultation($consultation_id: ID!, $diagnostic: String!, $recommandations: String, $notes: String) {
    terminerConsultation(
      consultation_id: $consultation_id
      diagnostic: $diagnostic
      recommandations: $recommandations
      notes: $notes
    ) {
      id
      statut
    }
  }
''';

const String dossierMedicalPatientQuery = r'''
  query DossierMedicalPatient($patient_id: ID!) {
    dossierMedicalPatient(patient_id: $patient_id) {
      id
      antecedents_medicaux
      allergies_connues
      medicaments_actuels
      groupe_sanguin
      poids
      taille
      imc
      notes_generales
    }
  }
''';

const String rechercherMedicamentQuery = r'''
  query RechercherMedicament($terme: String!) {
    rechercherMedicament(terme: $terme) {
      id
      nom_commercial
      principe_actif
      dosage
      forme
      prix_unitaire
    }
  }
''';

const String creerPrescriptionMutation = r'''
  mutation CreerPrescription($input: CreerPrescriptionInput!) {
    creerPrescription(input: $input) {
      id
    }
  }
''';
