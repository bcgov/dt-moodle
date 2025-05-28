FROM php:8.1-apache

# Install required PHP extensions and dependencies
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libxml2-dev \
    libzip-dev \
    libicu-dev \
    unzip \
    git \
    && rm -rf /var/lib/apt/lists/* \
    && docker-php-ext-install gd mysqli zip opcache intl soap exif

# Configure PHP
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
    && sed -i 's/memory_limit = .*/memory_limit = 256M/' "$PHP_INI_DIR/php.ini" \
    && sed -i 's/max_execution_time = .*/max_execution_time = 300/' "$PHP_INI_DIR/php.ini" \
    && sed -i 's/upload_max_filesize = .*/upload_max_filesize = 100M/' "$PHP_INI_DIR/php.ini" \
    && sed -i 's/post_max_size = .*/post_max_size = 100M/' "$PHP_INI_DIR/php.ini" \
    && sed -i 's/max_input_vars = .*/max_input_vars = 5000/' "$PHP_INI_DIR/php.ini"

# Create non-root user with OpenShift-compatible UID
RUN groupadd -g 1011470000 moodle \
    && useradd -u 1011470000 -g 1011470000 -s /sbin/nologin \
    -c "Moodle User" moodle

# Download and extract Moodle 4.5
RUN cd /var/www/html \
    && curl -fsSL https://download.moodle.org/download.php/direct/stable405/moodle-latest-405.tgz -o moodle.tgz \
    && tar -xzf moodle.tgz \
    && rm moodle.tgz \
    && mv moodle/* . \
    && rm -rf moodle \
    && mkdir /var/moodledata_secure \
    && chown -R moodle:moodle /var/www/html \
    && chown -R moodle:moodle /var/moodledata_secure \
    && chmod -R g=u /var/www/html \
    && chmod -R 0770 /var/moodledata_secure

# Configure Apache
RUN a2enmod rewrite \
    && a2enmod headers \
    && a2enmod remoteip \
    && sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf \
    && sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf \
    && sed -i 's/:80/:8080/g' /etc/apache2/sites-enabled/*.conf \
    && echo "ServerName localhost" >> /etc/apache2/apache2.conf \
    && sed -i 's/DirectoryIndex .*/DirectoryIndex index.php index.html/' /etc/apache2/apache2.conf \
    && echo "<Directory /var/www/html>" >> /etc/apache2/apache2.conf \
    && echo "  Options -Indexes +FollowSymLinks" >> /etc/apache2/apache2.conf \
    && echo "  AllowOverride All" >> /etc/apache2/apache2.conf \
    && echo "  Require all granted" >> /etc/apache2/apache2.conf \
    && echo "</Directory>" >> /etc/apache2/apache2.conf \
    && echo "" >> /etc/apache2/apache2.conf \
    && echo "# Deny access to sensitive directories and files" >> /etc/apache2/apache2.conf \
    && echo "# Block access to version control, Behat, tests, composer files, and other sensitive locations/files" >> /etc/apache2/apache2.conf \
    && echo '<DirectoryMatch "^/var/www/html/(\.git|\.svn|\.bzr|\.hg|vendor|node_modules)">' >> /etc/apache2/apache2.conf \
    && echo "    Require all denied" >> /etc/apache2/apache2.conf \
    && echo "</DirectoryMatch>" >> /etc/apache2/apache2.conf \
    && echo "" >> /etc/apache2/apache2.conf \
    && echo '<DirectoryMatch "/(tests|behat|fixtures)/">' >> /etc/apache2/apache2.conf \
    && echo "    Require all denied" >> /etc/apache2/apache2.conf \
    && echo "</DirectoryMatch>" >> /etc/apache2/apache2.conf \
    && echo "" >> /etc/apache2/apache2.conf \
    && echo "# Block specific files that should not be web accessible" >> /etc/apache2/apache2.conf \
    && echo '<FilesMatch "^(composer\.(json|lock)|phpunit\.xml(\.dist)?|environment\.xml|install\.xml|README.*|readme.*|UPGRADING.*|upgrade.*|\.feature|\.lock|\.log|\.stylelintrc|\.eslint.*|\.prettier.*|\.editorconfig)$">' >> /etc/apache2/apache2.conf \
    && echo "    Require all denied" >> /etc/apache2/apache2.conf \
    && echo "</FilesMatch>" >> /etc/apache2/apache2.conf \
    && echo "" >> /etc/apache2/apache2.conf \
    && echo "# Specifically protect admin/environment.xml if the generic FilesMatch isn't sufficient or too broad" >> /etc/apache2/apache2.conf \
    && echo "<Location \"/admin/environment.xml\">" >> /etc/apache2/apache2.conf \
    && echo "    Require all denied" >> /etc/apache2/apache2.conf \
    && echo "</Location>" >> /etc/apache2/apache2.conf \
    && echo "" >> /etc/apache2/apache2.conf \
    && echo "# Ensure directory listings are off for lib/classes (already set globally but can be reiterated or made stricter if needed)" >> /etc/apache2/apache2.conf \
    && echo "<Directory \"/var/www/html/lib/classes\">" >> /etc/apache2/apache2.conf \
    && echo "    Options -Indexes" >> /etc/apache2/apache2.conf \
    && echo "    # Allow access to PHP files if called internally by Moodle" >> /etc/apache2/apache2.conf \
    && echo "    Require all granted" >> /etc/apache2/apache2.conf \
    && echo "</Directory>" >> /etc/apache2/apache2.conf \
    && echo "" >> /etc/apache2/apache2.conf \
    && echo "RemoteIPHeader X-Forwarded-For" >> /etc/apache2/apache2.conf \
    && echo "RemoteIPTrustedProxy 10.0.0.0/8" >> /etc/apache2/apache2.conf \
    # && echo "SetEnvIf X-Forwarded-Proto https HTTPS=on" >> /etc/apache2/apache2.conf \
    # && echo "SetEnvIf X-Forwarded-Port 443 HTTPS=on" >> /etc/apache2/apache2.conf \
    # && echo "SetEnvIf X-Forwarded-Port 443 SERVER_PORT=443" >> /etc/apache2/apache2.conf \
    # && echo "SetEnvIf X-Forwarded-Host .* HTTP_HOST=\$0" >> /etc/apache2/apache2.conf \
    # && echo "SetEnvIf HTTPS on SERVER_PORT=443" >> /etc/apache2/apache2.conf \
    && echo "<FilesMatch \".+\.ph(ar|p|tml)$\">" >> /etc/apache2/apache2.conf \
    && echo "  SetHandler application/x-httpd-php" >> /etc/apache2/apache2.conf \
    && echo "</FilesMatch>" >> /etc/apache2/apache2.conf \
    && chown -R moodle:moodle /var/run/apache2 \
    && chown -R moodle:moodle /var/lock/apache2 \
    && chown -R moodle:moodle /var/log/apache2 \
    && chmod -R g=u /var/run/apache2 \
    && chmod -R g=u /var/lock/apache2 \
    && chmod -R g=u /var/log/apache2

# Create debug script to help diagnose URL issues
RUN echo '<?php' > /var/www/html/debug.php \
    && echo 'echo "<h1>Server Variables</h1>";' >> /var/www/html/debug.php \
    && echo 'echo "<pre>";' >> /var/www/html/debug.php \
    && echo 'echo "HTTP_HOST: " . $_SERVER["HTTP_HOST"] . "\n";' >> /var/www/html/debug.php \
    && echo 'echo "HTTPS: " . (isset($_SERVER["HTTPS"]) ? $_SERVER["HTTPS"] : "not set") . "\n";' >> /var/www/html/debug.php \
    && echo 'echo "SERVER_PORT: " . $_SERVER["SERVER_PORT"] . "\n";' >> /var/www/html/debug.php \
    && echo 'echo "HTTP_X_FORWARDED_PROTO: " . (isset($_SERVER["HTTP_X_FORWARDED_PROTO"]) ? $_SERVER["HTTP_X_FORWARDED_PROTO"] : "not set") . "\n";' >> /var/www/html/debug.php \
    && echo 'echo "HTTP_X_FORWARDED_PORT: " . (isset($_SERVER["HTTP_X_FORWARDED_PORT"]) ? $_SERVER["HTTP_X_FORWARDED_PORT"] : "not set") . "\n";' >> /var/www/html/debug.php \
    && echo 'echo "HTTP_X_FORWARDED_HOST: " . (isset($_SERVER["HTTP_X_FORWARDED_HOST"]) ? $_SERVER["HTTP_X_FORWARDED_HOST"] : "not set") . "\n";' >> /var/www/html/debug.php \
    && echo 'echo "REQUEST_URI: " . $_SERVER["REQUEST_URI"] . "\n";' >> /var/www/html/debug.php \
    && echo 'echo "SCRIPT_NAME: " . $_SERVER["SCRIPT_NAME"] . "\n";' >> /var/www/html/debug.php \
    && echo 'echo "PHP_SELF: " . $_SERVER["PHP_SELF"] . "\n";' >> /var/www/html/debug.php \
    && echo 'echo "</pre>";' >> /var/www/html/debug.php \
    && chown moodle:moodle /var/www/html/debug.php \
    && chmod g=u /var/www/html/debug.php

# Create a script to simulate Moodle URL construction
RUN echo '<?php' > /var/www/html/url-test.php \
    && echo 'echo "<h1>Moodle URL Simulation</h1>";' >> /var/www/html/url-test.php \
    && echo 'echo "<pre>";' >> /var/www/html/url-test.php \
    && echo '$protocol = isset($_SERVER["HTTPS"]) && $_SERVER["HTTPS"] === "on" ? "https" : "http";' >> /var/www/html/url-test.php \
    && echo '$host = $_SERVER["HTTP_HOST"];' >> /var/www/html/url-test.php \
    && echo '$port = $_SERVER["SERVER_PORT"];' >> /var/www/html/url-test.php \
    && echo '$path = dirname($_SERVER["SCRIPT_NAME"]);' >> /var/www/html/url-test.php \
    && echo '$wwwroot = $protocol . "://" . $host;' >> /var/www/html/url-test.php \
    && echo 'if ($port != "80" && $port != "443") {' >> /var/www/html/url-test.php \
    && echo '    $wwwroot .= ":" . $port;' >> /var/www/html/url-test.php \
    && echo '}' >> /var/www/html/url-test.php \
    && echo '$wwwroot .= $path;' >> /var/www/html/url-test.php \
    && echo 'echo "Protocol: " . $protocol . "\n";' >> /var/www/html/url-test.php \
    && echo 'echo "Host: " . $host . "\n";' >> /var/www/html/url-test.php \
    && echo 'echo "Port: " . $port . "\n";' >> /var/www/html/url-test.php \
    && echo 'echo "Path: " . $path . "\n";' >> /var/www/html/url-test.php \
    && echo 'echo "WWWROOT: " . $wwwroot . "\n";' >> /var/www/html/url-test.php \
    && echo 'echo "</pre>";' >> /var/www/html/url-test.php \
    && chown moodle:moodle /var/www/html/url-test.php \
    && chmod g=u /var/www/html/url-test.php

# Create a simple test file to verify Apache is working
RUN echo "<?php phpinfo(); ?>" > /var/www/html/test.php \
    && chown moodle:moodle /var/www/html/test.php \
    && chmod g=u /var/www/html/test.php

USER moodle
