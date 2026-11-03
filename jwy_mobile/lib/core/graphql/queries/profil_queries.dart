const String monProfilQuery = r'''
  query MonProfil {
    me {
      id
      email
      telephone
      role
      patient {
        id
        nom
        prenom
        date_naissance
        genre
        adresse
        numero_urgence
        groupe_sanguin
        allergies
      }
      medecin {
        id
        nom
        prenom
        numero_ordre
        specialite
        hopital_rattachement
        tarif_consultation
        biographie
        annees_experience
      }
      pharmacien {
        id
        nom
        prenom
        numero_ordre
        pharmacies {
          id
          nom_pharmacie
          adresse
          telephone
          livraison_disponible
        }
      }
    }
  }
''';

const String updateCompteMutation = r'''
  mutation UpdateCompte($input: UpdateCompteInput!) {
    updateCompte(input: $input) {
      id
      telephone
    }
  }
''';

const String updateProfilPatientMutation = r'''
  mutation UpdateProfil($input: UpdatePatientInput!) {
    updateProfil(input: $input) {
      id
    }
  }
''';

const String updateProfilMedecinMutation = r'''
  mutation UpdateProfilMedecin($input: UpdateMedecinInput!) {
    updateProfilMedecin(input: $input) {
      id
    }
  }
''';

const String updateProfilPharmacienMutation = r'''
  mutation UpdateProfilPharmacien($input: UpdatePharmacienInput!) {
    updateProfilPharmacien(input: $input) {
      id
    }
  }
''';

const String updateMaPharmacieMutation = r'''
  mutation UpdateMaPharmacie($input: UpdatePharmacieInput!) {
    updateMaPharmacie(input: $input) {
      id
    }
  }
''';

const String changerMotDePasseMutation = r'''
  mutation ChangerMotDePasse($ancien: String!, $nouveau: String!) {
    changerMotDePasse(ancien_mot_de_passe: $ancien, nouveau_mot_de_passe: $nouveau)
  }
''';
