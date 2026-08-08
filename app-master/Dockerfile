# Image officielle PHP 8.2 + Apache.
FROM php:8.2.8-apache

# Durcissement sécurité : désactive register_argc_argv pour neutraliser
# CVE-2024-52301 (manipulation de l'environnement Laravel via la query string).
# Le correctif applicatif (laravel/framework >= 8.83.28) n'est pas retenu seul
# car la branche 8.x est en fin de vie et reste affectée par d'autres avis de
# sécurité ; la mitigation au niveau PHP ferme la condition d'exploitation.
# Réf : https://nvd.nist.gov/vuln/detail/CVE-2024-52301
RUN printf "register_argc_argv = Off\n" > "$PHP_INI_DIR/conf.d/zz-hardening.ini"

# Extensions PHP nécessaires.
RUN docker-php-ext-install pdo_mysql

# Composer (binaire seul, pas d'outillage superflu conservé dans l'image).
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Copie de l'application (le .dockerignore exclut secrets, .env, compose, etc.).
COPY . /var/www/html/

# Installe les dépendances SANS les paquets de dev (CWE-489 : pas d'Ignition/
# Flare en prod) et optimise l'autoloader. Les outils de build (git/unzip) sont
# installés puis purgés dans la même couche pour garder une image runtime mince.
RUN apt-get update \
    && apt-get install -y --no-install-recommends git unzip \
    && composer install --no-dev --optimize-autoloader --no-interaction --no-progress \
    && composer clear-cache \
    && apt-get purge -y --auto-remove git unzip \
    && rm -rf /var/lib/apt/lists/*

# Apache écoute sur un port non privilégié (8080) pour pouvoir tourner en
# non-root, et journalise vers stdout/stderr (12-factor).
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
    && sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf \
    && sed -ri -e 's!Listen 80$!Listen 8080!' /etc/apache2/ports.conf \
    && sed -ri -e 's!:80>!:8080>!' /etc/apache2/sites-available/*.conf \
    && a2enmod rewrite \
    && echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf \
    && a2enconf servername

# Utilisateur non privilégié (CWE-250). uid 1000 pour s'aligner sur le
# securityContext du chart Helm (runAsUser: 1000).
RUN useradd -u 1000 -m -d /home/appuser -s /usr/sbin/nologin appuser \
    && chown -R 1000:1000 /var/www/html/storage /var/www/html/bootstrap/cache \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache \
    # Répertoires d'exécution/journaux Apache accessibles en écriture au
    # user non-root (uid 1000) : pid, verrous et logs.
    && chown -R 1000:1000 /var/run/apache2 /var/log/apache2 /var/lock

USER 1000

EXPOSE 8080
