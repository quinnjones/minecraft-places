# minecraft-places

A small, nearly self-contained web application to keep track of points of
interest in Minecraft.

# Usage

The general idea is that, as you wander around a Minecraft world, you'll
find things and places that you might want to come back to.

The application is divided into two parts: a grid to display recorded
locations, and a form to add new locations.

Locations are recorded using Minecraft's XYZ coordinate system. The Y
(altitude) coordinate is optional. Each location also records a name
and a type. Several useful types are already present.

Multiple worlds may be saved in the same database. Each world is
addressed using different names at the end of the URL.

For example, you may regularly visit worlds hosted by your friends
Roger, Stanley, and Tommy, as well as your own:

* http://hostname:3000/Me
* http://hostname:3000/Roger
* http://hostname:3000/Stanley
* http://hostname:3000/Tommy

There's no registration procedure. Accessing a URL and adding a place
is all that's required to configure it.

URLs are case-sensitive. /world views different data than /World.

# Requirements

* Perl

  Should work with any version from 5.10.0 and above (possibly even
  5.8.8, though I haven't tested that)

  * Mojolicious
  * DBI
  * DBD::SQLite (normally comes packaged with DBI)

Some javascript is also required. It's loaded via CDN but you may
choose to host it locally.

* jQuery
* jQuery.DataTables

## Apache Configuration

By using Apache as a proxy you can have "clean" URLs. Make sure that
the `proxy`, `proxy_html`, and `proxy_http` modules are installed,
then add something similar to your configuration:

    <Location /minecraft-places/>
        ProxyPass        "http://servername:3000/"
        ProxyPassReverse "http://servername:3000/"
    </Location>

You may choose to edit the source and use your own port numbers;
adjust accordingly. 

## Database and Schema

You must create and initialize an SQLite database according to the
default path, found in the DSN constant in the code.

The file `schema.sql` is provided for you. To use it, execute

    $ sqlite3 /path/to/db schema.sql

# Running the Endpoint

Use the Hypnotoad server included with Mojolicious.  Assuming that you
keep the program in the ```/srv/www/apps/minecraft-places``` directory,
execute:

    $ hypnotoad /srv/www/apps/minecraft-places/places.pl

The same command will start and gracefully reload the service.

