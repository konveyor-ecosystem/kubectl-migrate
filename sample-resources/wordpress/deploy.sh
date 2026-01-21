#!/bin/bash

# Seed secrets if empty (MySQL root, wordpress users and Wordpress admin user passwords)
if [ ! -f .env ]; then
PASS_MYSQL="$(openssl rand -base64 16)"
PASS_MYSQL_WORDPRESS="$(openssl rand -base64 16)"
PASS_WORDPRESS="$(openssl rand -base64 12)"

umask 077
cat > .env <<EOF
MYSQL_ROOT_PASSWORD=$PASS_MYSQL
MYSQL_WORDPRESS_PASSWORD=$PASS_MYSQL_WORDPRESS
WORDPRESS_ADMIN_PASSWORD=$PASS_WORDPRESS
EOF
fi
chmod 600 .env

echo "# Using kubectl context: $(kubectl config current-context)"

# Deploy
kubectl apply -k ./

# Wait until deployment is ready and WordPress correctly installed
echo "Waiting for install mysql, wordpress and install job to be completed..."
kubectl wait --for=condition=available --timeout=300s deployment/wordpress-mysql
kubectl wait --for=condition=available --timeout=120s deployment/wordpress
kubectl wait --for=condition=complete --timeout=120s job.batch/wordpress-install

#echo "Open with 'minikube service wordpress' or 'kubectl port-forward svc/wordpress 8080:80' and open http://127.0.0.1:8080/ in browser"