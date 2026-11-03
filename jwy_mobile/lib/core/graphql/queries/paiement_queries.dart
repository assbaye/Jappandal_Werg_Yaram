const String initierPaiementMutation = r'''
  mutation InitierPaiement($input: InitierPaiementInput!) {
    initierPaiement(input: $input) {
      ... on PaiementMobileResponse {
        paiement_id
        payment_url
        ussd_code
        reference
        message
      }
      ... on PaiementStripeResponse {
        paiement_id
        client_secret
        publishable_key
      }
    }
  }
''';

const String verifierPaiementMutation = r'''
  mutation VerifierPaiement($paiement_id: ID!) {
    verifierPaiement(paiement_id: $paiement_id) {
      id
      statut
      montant
      methode_paiement
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
        methode_paiement
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
