#!/bin/bash
ID=$1
CONTAINER_NAME="nginx_server"

# 1. SOURCES DES VARIABLES ESSENTIELLES
    #  1.1 PATH : POSITION DES FICHIERS ESSENTIELS
        BASE_PATH=$(pwd)
        ENV_FILE_SERVER="$BASE_PATH/Server.env"
        TEMPLATES_PATH="$BASE_PATH/Templates"
        TEMPLATE_NGINX_FILE="$TEMPLATES_PATH/NginxDomainHttp.conf"
        ERROR_PATH="$TEMPLATES_PATH/errors"

    # 1.2 ID ET PATH : VALIDATION DES PARAMETRES
        # Vérifier si l'ID a été fourni
        if [ -z "$ID" ]; then
            echo "Erreur #1 : Veuillez fournir un ID."
            exit 1
        fi
        # Vérifier si le fichier .env existe
        if [ ! -f "$ENV_FILE_SERVER" ]; then
            echo "Erreur #2 : Le fichier $ENV_FILE_SERVER n'existe pas."
            exit 1
        fi

        if [ ! -f "$TEMPLATE_NGINX_FILE" ]; then
            echo "Erreur #3 : Le fichier template Nginx $TEMPLATE_NGINX_FILE n'existe pas."
            exit 1
        fi

# 2. ENV : RÉCUPERATION DES VALEURS
    # 2.1 ENV SERVER : RÉCUPERATION DES VALEURS
    APPNAME=$(grep "^${ID}_APPNAME=" "$ENV_FILE_SERVER" | cut -d'=' -f2 | tr -d '"' | tr -d "'" | xargs)
    DOMAINS=$(grep "^${ID}_DOMAIN=" "$ENV_FILE_SERVER" | cut -d'=' -f2 | tr -d '"' | tr -d "'" | xargs)
    PORT80=$(grep "^${ID}_PORT80=" "$ENV_FILE_SERVER" | cut -d'=' -f2 | tr -d '"' | tr -d "'" | xargs)
    PORT443=$(grep "^${ID}_PORT443=" "$ENV_FILE_SERVER" | cut -d'=' -f2 | tr -d '"' | tr -d "'" | xargs)
    ADMINEMAIL=$(grep "^${ID}_ADMIN_EMAIL=" "$ENV_FILE_SERVER" | cut -d'=' -f2 | tr -d '"' | tr -d "'" | xargs)
    SERVER1=$(grep "^${ID}_SERVER1=" "$ENV_FILE_SERVER" | cut -d'=' -f2 | tr -d '"' | tr -d "'" | xargs)
    SERVER2=$(grep "^${ID}_SERVER2=" "$ENV_FILE_SERVER" | cut -d'=' -f2 | tr -d '"' | tr -d "'" | xargs)
    SERVER3=$(grep "^${ID}_SERVER3=" "$ENV_FILE_SERVER" | cut -d'=' -f2 | tr -d '"' | tr -d "'" | xargs)
    NGINX_CONF_FILE="./nginx/sites-enabled/${APPNAME}.conf"

    # 2.2 ENV : VALIDATION DES VALEURS
        if [ -z "$APPNAME" ] || [ -z "$DOMAINS" ] || [ -z "$ADMINEMAIL" ]; then
            echo "Erreur : Informations manquantes pour l'ID $ID"
            echo "APPNAME : $APPNAME"
            echo "DOMAINS : $DOMAINS"
            echo "PORT80 : $PORT80"
            echo "ADMINEMAIL : $ADMINEMAIL"
            echo "SERVER1 : $SERVER1"
            echo "SERVER2 : $SERVER2"
            echo "SERVER3 : $SERVER3"
            exit 1
        fi



# EXECUTION ###########################################################################################

# DOCKER : SHAREDNETWORK - VALIDATION ET CREATION SI REQUIS

    if ! docker network inspect "server_network" &> /dev/null; then
        echo "Le réseau partagé server_network Docker n'existe pas. Création du réseau..."
        if docker network create "server_network"; then
            echo "Réseau server_network créé avec succès."
        else
            echo "Erreur lors de la création du réseau server_network."
            exit 1
        fi
    else
        echo "Le réseau Docker server_network requis est actif et prêt à l'emploi."
    fi




# TEMPLATE : COPIE DES TEMPLATES
    cp "$TEMPLATE_NGINX_FILE" "$NGINX_CONF_FILE"
# TEMPLATE : REMPLACEMENT DES VARIABLES
    # Nginx Domain conf
    sed -i \
        "s/ID/$ID/g; \
        s/DOMAIN/$DOMAINS/g; \
        s/APPNAME/$APPNAME/g; \
        s/PORT80/$PORT80/g; \
        s/SERVER1/$SERVER1/g; \
        s/SERVER2/$SERVER2/g; \
        s/SERVER3/$SERVER3/g" \
        "$NGINX_CONF_FILE"
    echo
    echo "Le fichier NGINX à été configuré avec les variables suivantes :"
    echo "Nom de domaine : $DOMAINS"
    echo "Nom de l'application : $APPNAME"
    echo "Serveur 1 : $SERVER1"
    echo "Serveur 2 : $SERVER2"
    echo "Serveur 3 : $SERVER3"
    echo

# DOCKER-NGINX : Vérification si le conteneur NGINX est actif
    echo
    echo "Vérification de l'état du conteneur $CONTAINER_NAME"
    if ! docker inspect "$CONTAINER_NAME" &> /dev/null; then
        echo "Le conteneur $CONTAINER_NAME n'existe pas. Démarrage du conteneur..."
        if ! docker-compose up -d nginx_server; then
            echo "Erreur lors de la création ou du démarrage du conteneur $CONTAINER_NAME"
            exit 1
        else
            echo
            echo "Le conteneur $CONTAINER_NAME a démarré avec succès"
            echo
        fi
    else
        # Vérifier si le conteneur est en cours d'exécution
        if [ "$(docker inspect -f '{{.State.Running}}' $CONTAINER_NAME)" != "true" ]; then
            echo "Le conteneur $CONTAINER_NAME n'est pas actif. Tentative de démarrage..."
            if ! docker-compose up -d nginx_server; then
                echo "Erreur lors du démarrage du conteneur $CONTAINER_NAME"
                exit 1
            else
                echo "Le conteneur $CONTAINER_NAME a démarré avec succès"
            fi
        else
            echo "Le conteneur $CONTAINER_NAME est actif"
        fi
    fi


# DOCKER-NGINX : Vérification de la syntaxe du fichier de configuration NGINX et rechargement
    echo
    echo "Vérification de la syntaxe du fichier de configuration NGINX avant application"
    echo
    if ! docker exec $CONTAINER_NAME nginx -t ; then
        echo "Erreur de syntaxe dans le fichier de configuration NGINX."
        echo "Aucun changement n'est appliqué"
        mv "$NGINX_CONF_FILE" $ERROR_PATH
        echo "Vérifiez que les variables sont correctes dans le fichier environnement $ENV_FILE_SERVER et que le template $TEMPLATES_PATH est bien formaté."
        echo "Le fichier de configuration généré est déplacer dans le dossier $ERROR_PATH"
        exit 1
    else
        echo "Syntaxe correcte du fichier de configuration NGINX"
        echo "### Application du fichier de configuration NGINX ..."
        echo "### Rechargement de nginx ..."
        docker-compose exec $CONTAINER_NAME nginx -s reload
        if [ "$(docker inspect -f '{{.State.Running}}' $CONTAINER_NAME)" != "true" ]; then
            echo "Erreur lors du rechargement du conteneur $CONTAINER_NAME"
            exit 1
        else
            echo "Le conteneur $CONTAINER_NAME a démarré avec succès"
        fi
    fi
