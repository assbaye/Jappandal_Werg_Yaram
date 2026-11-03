const String _alerteFields = r'''
      id
      statut
      type_urgence
      description
      latitude
      longitude
      prise_en_charge_le
      created_at
      medecin {
        id
        nom
        prenom
        user {
          telephone
        }
      }
      patient {
        id
        nom
        prenom
        age
        groupe_sanguin
        allergies
        numero_urgence
        user {
          telephone
        }
      }
''';

const String monAlerteUrgenceQuery = '''
  query MonAlerteUrgence {
    monAlerteUrgence {
$_alerteFields
    }
  }
''';

const String alertesUrgenceQuery = '''
  query AlertesUrgence {
    alertesUrgence {
$_alerteFields
    }
  }
''';

const String declencherAlerteUrgenceMutation = '''
  mutation DeclencherAlerteUrgence(\$latitude: Float!, \$longitude: Float!, \$type_urgence: String!, \$description: String) {
    declencherAlerteUrgence(latitude: \$latitude, longitude: \$longitude, type_urgence: \$type_urgence, description: \$description) {
$_alerteFields
    }
  }
''';

const String prendreEnChargeUrgenceMutation = r'''
  mutation PrendreEnChargeUrgence($id: ID!) {
    prendreEnChargeUrgence(id: $id) {
      id
      statut
    }
  }
''';

const String terminerAlerteUrgenceMutation = r'''
  mutation TerminerAlerteUrgence($id: ID!) {
    terminerAlerteUrgence(id: $id) {
      id
      statut
    }
  }
''';
