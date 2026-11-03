const String analyserSymptomesMutation = r'''
  mutation AnalyserSymptomes($symptomes: String!) {
    analyserSymptomes(symptomes: $symptomes) {
      id
      symptomes
      niveau_urgence
      specialite_recommandee
      type_consultation
      explication
      conseils
      signes_alerte
    }
  }
''';
