#!/bin/bash
echo "Zaczynam"

SERVER_IP="$1"
SERVER_PORT=$2
#FRONT_PORT=$3

cd /root
sudo apt update
sudo apt upgrade -y
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.8/install.sh | bash

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

nvm install 16
git clone https://github.com/spring-petclinic/spring-petclinic-angular
cd spring-petclinic-angular
#sed -i "s/localhost/$SERVER_IP/g" src/environments/environment.prod.ts src/environments/environment.ts
sed -i 's|http://[^"]*||g' src/environments/environment*.ts
#sed -i "s/9966/$SERVER_PORT/g" src/environments/environment.prod.ts src/environments/environment.ts
npm install
#npm install -g angular-http-server
npm run build -- --configuration production
#nohup npx angular-http-server --path ./dist -p $FRONT_PORT > angular.out 2> angular.err &

# Instalacja i konfiguracja Nginx jako reverse proxy
sudo apt-get install -y nginx

cat <<EOF | sudo tee /etc/nginx/sites-available/petclinic.conf
server {
    listen 80;
    server_name _;
    root /root/spring-petclinic-angular/dist/spring-petclinic-angular;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /petclinic/ {
        proxy_pass http://$SERVER_IP:$SERVER_PORT/petclinic/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/petclinic.conf /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo systemctl restart nginx
#sudo pkill -f angular-http-server
#sudo systemctl start nginx