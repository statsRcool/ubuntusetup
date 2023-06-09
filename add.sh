#!/usr/bin/env bash

clear

function create_sudo_user(){
    read -p "Set sudo user: " username;
    (adduser $username && usermod -aG sudo $username);
}

function switch_sudo_users(){
    read -p "Switch user to: " username;
    (su - $username && sudo whoami);
}

function install_git(){
    echo "Installing git...";
    (sudo apt update && sudo apt install git);
    echo "Checking git version...";
    (git --version);
    (git config --global user.name "Collin Paran" && git config --global user.email "collin@collinparan.com");
    #If errors make sure noclobber is set to false
    # set -o | grep noclobber;
}

function setup_git(){
    #git@github.com:username/new_repo
    read -p "Set remote git url: " remotegiturl;
    read -p "Set remote git name (ex. origin): " remotegitname;
    read -p "Set local git dir: " localgitdir;
    echo "Adding git remote...";
    (git remote add $remotegitname $remotegiturl);
    echo "Setting up local git dir and initial pull...";
    (cd ~ && mkdir $localgitdir && cd $localgitdir && git pull $remotegitname master && git fetch $remotegitname && git push $remotegitname master);
    echo "Listing all git remotes...";
    (git remote -v);
}


function setup_codeserver_vm(){
    echo "Getting code server v4.11.0 tar...";
    (wget https://github.com/coder/code-server/releases/download/v4.11.0/code-server-4.11.0-linux-amd64.tar.gz);
    echo "Extracting tar...";
    (tar -xvzf code-server-4.11.0-linux-amd64.tar.gz);
    echo "Moving code-server to bin folder...";
    (cd code-server-4.11.0-linux-amd64 && mv code-server /bin && cd .. && rm -rf code-server-4.11.0-linux-amd64 && rm code-server-4.11.0-linux-amd64.tar.gz);
}

function setup_codeserver_service(){
    read -p "Set code server password: " coderpass;
    echo "Creating service file...";
    (cd /etc/systemd/system && echo "[Unit]
Description=Code Server AutoStart
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service

[Service]
Type=simple
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
Restart=on-failure

ExecStart=/usr/bin/sudo /bin/code-server --allow-http --password=\"$coderpass\" -p 8080

[Install]
WantedBy=multi-user.target" > codeserver.service);
    echo "Starting service...";
    (sudo systemctl daemon-reload && sudo systemctl enable codeserver.service && sudo systemctl start codeserver.service);
}

function start_codeserver(){
    read -p "Set code server password: " codeserverpass;
    echo "Starting code server..."
    (sudo code-server --password="$codeserverpass" --allow-http -p 8080);
}

function codeserver_serverblock(){
    read -p "Domain or dot com: " domain;
    echo "Creating nginx sites available file...";
    (cd /etc/nginx/sites-available && echo "server {
        listen 80;
        listen [::]:80;
        server_name $domain;

        location / {
        proxy_pass http://localhost:8080/;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection upgrade;
        proxy_set_header Accept-Encoding gzip;
        }
}" > $domain);
    echo "Creating symlink...";
    (sudo ln -s /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/);
    echo "Uncomment 'server_names_hash_bucket_size' & restart nginx...";
    (sudo nano /etc/nginx/nginx.conf);
}

function install_nginx(){
    echo "Installing nginx...";
    (sudo apt update && sudo apt install nginx);
    echo "Setting up ufw...";
    (sudo ufw app list && sudo ufw allow ssh && sudo ufw allow 22 &&  sudo ufw allow 8080 && sudo ufw allow 8787 && sudo ufw allow 'Nginx Full' && sudo ufw enable && sudo ufw status verbose);
}

function setup_nginx_serverblock(){
    read -p "Domain or dot com: " domain;
    (sudo mkdir -p /var/www/$domain/html && sudo chown -R $USER:$USER /var/www/$domain/html && sudo chmod -R 755 /var/www/$domain);
    echo "Creating initial html...";
    (cd /var/www/$domain/html && echo "<title>$domain</title>
    </head>
    <body>
        <h1>Success!  The $domain server block is working!</h1>
    </body>
    </html>" > index.html);
    echo "Creating nginx sites available file...";
    (cd /etc/nginx/sites-available && echo "server {
        listen 80;
        listen [::]:80;

        root /var/www/$domain/html;
        index index.html index.htm index.nginx-debian.html;

        server_name $domain;

        location / {
            # First attempt to serve request as file, then
            # as directory, then fall back to displaying a 404.
            try_files \$uri \$uri/ =404;
        }
    }" > $domain);
    echo "Creating symlink...";
    (sudo ln -s /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/);
    echo "Uncomment 'server_names_hash_bucket_size' & restart nginx...";
    (sudo nano /etc/nginx/nginx.conf);
}

function restart_nginx_service(){
    echo "Testing nginx...";
    (sudo nginx -t);
    echo "Restarting nginx service...";
    (sudo systemctl restart nginx);
}

function install_certbot(){
    echo "Installing certbot...";
    (sudo add-apt-repository ppa:certbot/certbot);
    echo "Installing python certbot for nginx...";
    (sudo apt install python-certbot-nginx);
}

function get_ssl(){
    read -p "Domain or dot com: " domain;
    (sudo certbot --nginx -d $domain);
    echo "Verifying auto-renewal process...";
    (sudo certbot renew --dry-run);
}


echo "Which would you like to do?"
select pd in "install_git" "setup_git" "setup_codeserver" "setup_codeserver_serverblock" "setup_codeserver_service" "install_certbot" "get_ssl" "only_start_codeserver" "install_nginx" "setup_nginx_serverblock" "restart_nginx_service" "create_sudo_user" "exit"; do 
    case $pd in 
        install_git ) install_git; exit;;
        setup_git ) setup_git; exit;;
        setup_codeserver ) setup_codeserver_vm; start_codeserver; exit;;
        setup_codeserver_serverblock ) codeserver_serverblock; exit;;
        setup_codeserver_service ) setup_codeserver_service; exit;;
        install_certbot ) install_certbot; exit;;
        get_ssl ) get_ssl; exit;;
        only_start_codeserver ) start_codeserver; exit;;
        install_nginx ) install_nginx; exit;;
        setup_nginx_serverblock ) setup_nginx_serverblock; exit;;
        restart_nginx_service ) restart_nginx_service; exit;;
        create_sudo_user ) create_sudo_user; exit;;
        exit ) exit;;
    esac
done
