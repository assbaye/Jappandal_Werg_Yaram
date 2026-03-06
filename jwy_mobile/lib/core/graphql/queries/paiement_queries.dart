const String initierPaiementMutation = r'''
  mutation InitierPaiement($input: PaiementInput!) {
    initierPaiement(input: $input) {
      paiement {
        id
        montant
        statut
        methode
        numero_transaction
      }
      redirect_url
      client_secret
    }
  }
''';

const String confirmerPaiementMutation = r'''
  mutation ConfirmerPaiement($transactionId: String!) {
    confirmerPaiement(transactionId: $transactionId) {
      id
      statut
      facture {
        numero_facture
        montant_ttc
      }
    }
  }
''';

const String mesPaiementsQuery = r'''
  query MesPaiements($first: Int, $page: Int) {
    mesPaiements(first: $first, page: $page) {
      data {
        id
        montant
        devise
        statut
        methode
        created_at
        facture {
          numero_facture
        }
      }
      paginatorInfo {
        hasMorePages
        currentPage
      }
    }
  }
''';
