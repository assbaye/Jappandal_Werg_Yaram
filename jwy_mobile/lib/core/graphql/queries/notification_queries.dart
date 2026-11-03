const String mesNotificationsQuery = r'''
  query MesNotifications($first: Int, $page: Int) {
    mesNotifications(first: $first, page: $page) {
      data {
        id
        titre
        message
        type
        est_lue
        data
        created_at
      }
      paginatorInfo {
        hasMorePages
        currentPage
      }
    }
  }
''';

const String notificationsNonLuesQuery = r'''
  query NotificationsNonLues {
    me {
      id
      notifications_non_lues
    }
  }
''';

const String marquerNotificationLueMutation = r'''
  mutation MarquerNotificationLue($id: ID!) {
    marquerNotificationLue(id: $id) {
      id
      est_lue
    }
  }
''';

const String marquerToutesLuesMutation = r'''
  mutation MarquerToutesLues {
    marquerToutesLues
  }
''';
