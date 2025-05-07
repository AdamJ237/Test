#!/bin/bash
# użycie: ./deploy_front.sh <PUBLIC_IP_BACKEND> 8080

set -euxo pipefail

SERVER_IP="$1"      # publiczne IP backendVM
SERVER_PORT="$2"    # zwykle 8080

#  1. NVM + Node + repo 
APP_DIR="/spring-petclinic-angular"
BUILD_DIR="$APP_DIR/dist"      # w tym projekcie dist/ zawiera pliki bez dodatkowego podkatalogu

curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.8/install.sh | bash
export NVM_DIR="$HOME/.nvm"
source "$NVM_DIR/nvm.sh"

nvm install 16
git clone https://github.com/spring-petclinic/spring-petclinic-angular "$APP_DIR"
cd "$APP_DIR"

#  2. podmiana URL‑i API → /petclinic/api 
sed -i "s|'http://[^']*'|'/petclinic/api'|g" src/environments/environment*.ts

#  3. build Angulara 
npm install
npm run build -- --configuration production   # tworzy katalog dist/

#  4. deploy statycznych plików 
sudo mkdir -p /var/www/petclinic
sudo cp -r "$BUILD_DIR"/* /var/www/petclinic/
sudo chown -R www-data:www-data /var/www/petclinic

#  5. instalacja Nginx + konfig 
sudo apt-get install -y nginx

sudo tee /etc/nginx/sites-available/petclinic.conf > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    root /var/www/petclinic;

    # SPA – wszystko poza /petclinic/api/* trafia do index.html
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Backend REST
    location /petclinic/api/ {
        proxy_pass http://$SERVER_IP:$SERVER_PORT/petclinic/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/petclinic.conf /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
