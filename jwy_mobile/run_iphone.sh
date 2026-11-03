#!/bin/zsh
# Lance l'app sur l'iPhone branché en pointant vers le backend du Mac (IP détectée automatiquement).
IP=$(ipconfig getifaddr en0 || ipconfig getifaddr en1)
if [ -z "$IP" ]; then
  echo "Aucune IP réseau trouvée : le Mac est-il connecté au Wi-Fi ?"; exit 1
fi
echo "Backend : http://$IP:8001/graphql"
cd "$(dirname "$0")"
flutter run -d 00008030-00162C891E80802E --dart-define=API_URL=http://$IP:8001/graphql "$@"
