# NGINX SERVER

## Ligne de commande pratique

1. Permission pour un utilisateur et un répertoire spécifique :
```bash
sudo setfacl -R -m u:USERNAME:rwx /path/to/file
```

2. Lancer les containers :
    Sélectionnez le ID ou ajouter le domaine que vous souhaitez activer dans Server.env
```bash
yarn setupserver ID
yarn serverup
```

# Configuration de Nginx comme Reverse Proxy dans un Environnement Docker

La configuration de Nginx comme reverse proxy dans un environnement Docker permet de gérer efficacement le routage et la sécurisation de multiples sites web ou applications. Cette approche implique généralement l'utilisation de deux conteneurs Nginx : un premier qui écoute sur le port 80 et redirige le trafic en fonction du nom de domaine, et un second qui gère HTTPS et redirige vers les services spécifiques. Cette architecture offre une séparation des responsabilités, une flexibilité accrue et une meilleure gestion de la sécurité, tout en permettant d'héberger plusieurs sites sur une même infrastructure Docker.

## Premier Reverse Proxy Nginx

Le premier conteneur Nginx agit comme point d'entrée pour tout le trafic entrant, écoutant sur le port 80 (HTTP) et redirigeant les requêtes vers le second Nginx en fonction des noms de domaine. Sa configuration inclut typiquement des blocs `server` pour chaque domaine, avec des directives `proxy_pass` pointant vers le second conteneur Nginx approprié. Cette configuration permet :

- Gestion centralisée du trafic
- Ajout facile de nouveaux domaines sans modifier le point d'entrée principal
- Amélioration de la sécurité en isolant le composant exposé au public
- Distribution de charge efficace sur plusieurs services backend

L'utilisation de variables d'environnement comme `VIRTUAL_HOST` et `VIRTUAL_PORT` dans la configuration Docker facilite la configuration dynamique du reverse proxy, permettant une intégration transparente avec les capacités de mise en réseau de Docker.

## Gestion HTTPS par le Second Nginx

Le second conteneur Nginx gère les connexions HTTPS et redirige le trafic vers des services backend spécifiques. Il écoute sur le port 443 au sein de son réseau Docker, gérant la terminaison SSL pour chaque domaine. Cette configuration offre plusieurs avantages :

- Gestion isolée des certificats SSL pour chaque site
- Processus de renouvellement de certificats simplifié
- Capacité de mise à l'échelle individuelle des services
- Sécurité renforcée grâce à la segmentation du réseau

La configuration inclut généralement des blocs `server` séparés pour chaque domaine, avec les chemins des certificats SSL et les directives `proxy_pass` vers les services backend appropriés. Cette approche permet une mise à l'échelle flexible et l'ajout facile de nouveaux services sans impacter la configuration principale du reverse proxy.

## Configuration Docker-Compose Révisée

La configuration Docker Compose révisée pour le premier Nginx supprime les volumes liés à Certbot et maintient les paramètres essentiels. Les changements clés incluent :

- Suppression des volumes : `./data/certs/conf:/etc/letsencrypt` et `./data/certbot/www:/var/www/certbot`
- Maintien du mapping de port `70:80` pour le trafic HTTP
- Préservation de la commande pour le rechargement périodique de Nginx

La configuration utilise toujours `nginx:1.15-alpine` comme image de base et monte les volumes nécessaires pour la configuration, les logs et les fichiers HTML. Bien que la syntaxe de la commande puisse montrer une erreur lors de l'analyse, elle fonctionne généralement correctement dans les environnements Docker. Cette configuration offre une configuration de reverse proxy simplifiée, axée sur la gestion du trafic HTTP sans gestion SSL intégrée.

## Recommandations pour la Gestion SSL

Avec la suppression de Certbot, des stratégies alternatives de gestion SSL doivent être envisagées. L'obtention et le renouvellement manuel des certificats SSL auprès d'une Autorité de Certification de confiance est une option, nécessitant des mises à jour périodiques pour maintenir la fonctionnalité HTTPS. Alternativement, la mise en œuvre d'un conteneur séparé pour la gestion SSL, tel que Traefik ou HAProxy, peut automatiser les processus d'acquisition et de renouvellement des certificats. Ces solutions peuvent s'intégrer parfaitement à la configuration Nginx existante, assurant le support continu du HTTPS sans compromettre le modèle de sécurité isolé du conteneur Nginx principal.
