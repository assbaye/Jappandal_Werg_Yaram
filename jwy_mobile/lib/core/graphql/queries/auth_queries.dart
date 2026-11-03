const String loginMutation = r'''
  mutation Login($email: String!, $password: String!) {
    login(email: $email, password: $password) {
      access_token
      token_type
      expires_in
      user {
        id
        email
        role
        patient {
          id
          numero_patient
          nom
          prenom
        }
      }
    }
  }
''';

const String registerMutation = r'''
  mutation Register($input: RegisterInput!) {
    register(input: $input) {
      access_token
      token_type
      expires_in
      user {
        id
        email
        role
      }
    }
  }
''';

const String meQuery = r'''
  query Me {
    me {
      id
      email
      role
      patient {
        id
        numero_patient
        nom
        prenom
        adresse
        groupe_sanguin
      }
    }
  }
''';

const String logoutMutation = r'''
  mutation Logout {
    logout
  }
''';
