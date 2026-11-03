const String mesRendezVousQuery = r'''
  query MesRendezVous($first: Int, $page: Int, $statut: StatutRendezVous) {
    mesRendezVous(first: $first, page: $page, statut: $statut) {
      data {
        id
        date_rendez_vous
        duree_estimee
        statut
        type_rendez_vous
        lieu_rendez_vous
        motif
        medecin {
          id
          nom
          prenom
          specialite
        }
        patient {
          id
          nom
          prenom
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

const String prendreRendezVousMutation = r'''
  mutation PrendreRendezVous($input: PrendreRendezVousInput!) {
    prendreRendezVous(input: $input) {
      id
      statut
      date_rendez_vous
    }
  }
''';

const String repondreRendezVousMutation = r'''
  mutation RepondreRendezVous($id: ID!, $accepter: Boolean!, $motif: String) {
    repondreRendezVous(id: $id, accepter: $accepter, motif: $motif) {
      id
      statut
    }
  }
''';

const String annulerRendezVousMutation = r'''
  mutation AnnulerRendezVous($id: ID!) {
    annulerRendezVous(id: $id) {
      id
      statut
    }
  }
''';

const String reporterRendezVousMutation = r'''
  mutation ReporterRendezVous($id: ID!, $nouvelle_date: DateTime!) {
    reporterRendezVous(id: $id, nouvelle_date: $nouvelle_date) {
      id
      statut
      date_rendez_vous
    }
  }
''';
