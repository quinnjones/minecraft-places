#!/usr/bin/env perl

use strict;
use warnings;

use DBI;
use Mojolicious::Lite;

use constant DSN => 'dbi:SQLite:dbname=/srv/www/apps/minecraft-places/places.sqlite';
use constant DB_USERNAME => '';
use constant DB_PASSWORD => '';

app->config( hypnotoad => { listen => [ 'http://*:3000' ],
			    proxy  => 1,
			  } );
app->mode( 'development' );

get '/#instance' => sub {
    my $c = shift;

    $c->stash( instance => $c->param( 'instance' ) );
    $c->render( template => 'index' );
};

use constant SELECT_SQL => <<'SQL';
SELECT *
  FROM coordinates
 WHERE instance = ?
SQL

get '/#instance/data' => sub {
    my $c = shift;

    my $instance = $c->param( 'instance' );

    my $dbh = dbh();

    my $sth = $dbh->prepare_cached( SELECT_SQL );

    my $rows = $dbh->selectall_arrayref( $sth, { Slice => {} }, $instance );

    $c->render( template => 'default',
                json => { data => $rows } );
};

use constant INSERT_SQL => <<'SQL';
INSERT INTO coordinates ( instance,
                          name,
                          type,
                          x,
                          y,
                          z,
                          ipaddr,
                          created
                        )
                 VALUES ( ?, ?, ?, ?, ?,
                          ?, ?, CURRENT_TIMESTAMP )
SQL

post '/#instance/add' => sub {
    my $c = shift;
    my $v = $c->validation;

    my %rv = ( status => 500,
               json   => { code    => 'bad request',
                           message => 'unknown',
                           status  => 'error',
                         },
             );

    # the 'num' built in doesn't handle negative numbers properly
    $v->validator->add_check( integer => sub {
        my ( $v, $name, $value ) = @_;
        return ( !defined $value or $value !~ /^(-?\d+)$/ );
    });

    if ( $v->has_data ) {
        $v->required( 'name', 'trim' );
        $v->required( 'type', 'trim' );
        $v->required( 'x',    'trim' )->integer;
        $v->optional( 'y',    'trim' )->integer; # altitude isn't normally important
        $v->required( 'z',    'trim' )->integer;

        my %loc = ( instance => $c->param( 'instance' ) );

        foreach my $param ( @{ $v->passed } ) {
            $loc{ $param } = $v->param( $param );
        }

        if ( grep {!defined} @loc{qw( name type x z )} ) {
            %rv = ( status => 400,
                    json   => { code    => 'bad parameter',
                                message => 'One or more required parameters are missing (only Y is optional)',
                                status  => 'error',
                                passed  => [ $v->passed ],
                              },
                  );
        }
        else {
            my $dbh = dbh();

            local $dbh->{RaiseError} = 1;
            local $dbh->{AutoCommit} = 0;

            $loc{ipaddr} = $c->req->url->to_abs->host;

            my $inserted = eval {
                my $sth = $dbh->prepare_cached( INSERT_SQL );

                $sth->execute( @loc{qw( instance name type x y z ipaddr )} )
                    or die "Failed to insert: ".$dbh->errstr;
            };

            if ( !$inserted ) {
                #$c->debug( $@ ) if $@;

                %rv = ( status => 500,
                        json   => { code    => 'failed',
                                    message => 'An internal error occurred',
                                    status  => 'error',
                                  },
                      );
            }
            else {
                %rv = ( status => 202,
                        json   => { code    => 'accepted',
                                    message => 'Location has been saved',
                                    status  => 'ok',
                                  },
                      );

                my $referrer = $c->res->headers->referrer;
            }
        }
    }

    $c->render( %rv );
};

use constant SELECT_PLACE_SQL => <<'SQL';
SELECT *
  FROM coordinates
 WHERE instance = ?
   AND name     = ?
SQL

use constant DELETE_PLACE_SQL => <<'SQL';
DELETE FROM coordinates
      WHERE instance = ?
        AND name     = ?
SQL

del '/#instance/del/#place' => sub {
    my $c = shift;

    my $instance = $c->param( 'instance' );
    my $place    = $c->param( 'place' );

    my %rv = ( status => 500,
               json   => { code    => 'bad request',
                           message => 'unknown',
                           status  => 'error',
                         },
             );

    my $dbh = dbh();

    local $dbh->{RaiseError} = 1;
    local $dbh->{AutoCommit} = 0;

    my $deleted = eval {
        my $select_sth = $dbh->prepare_cached( SELECT_PLACE_SQL );

        my $existing = $dbh->selectrow_hashref( $select_sth,
                                                undef,
                                                $instance,
                                                $place,
                                              );

        my $delete_sth = $dbh->prepare_cached( DELETE_PLACE_SQL );

        $delete_sth->execute( $instance,
                              $place,
                            )
            or die "Failed to delete '$place': ".$dbh->errstr;

        $c->app->log->debug( join( ' ',
                                   'deleting',
                                   @{ $existing }{qw( instance type name x y z )},
                                 )
                           );
    };

    if ( !$deleted ) {
        if ( $@ ) {
            %rv = ( status => 500,
                    json   => { code    => 'failed',
                                message => 'An internal error occurred',
                                status  => 'error',
                              },
                  );
        }
        else {
            %rv = ( status => 404,
                    json   => { code    => 'not found',
                                message => "'$place' not found",
                                status  => 'failed',
                              },
                  );
        }
    }
    else {
        %rv = ( status => 200,
                json   => { code    => 'deleted',
                            message => "'$place' deleted",
                            status  => 'ok',
                          },
              );
    }

    $c->render( %rv );
};

app->start;

sub dbh
{
    return DBI->connect_cached( DSN, DB_USERNAME, DB_PASSWORD );
}

=head1 SCHEMA

 CREATE TABLE coordinates ( id       INTEGER,
                            instance TEXT,
                            x        INTEGER,
                            y        INTEGER,
                            z        INTEGER,
                            name     TEXT,
                            type     TEXT,
                            created  DATE,
                            ipaddr   TEXT,

                            PRIMARY KEY ( id )
                          );

 CREATE INDEX IF NOT EXISTS instanceidx ON coordinates ( instance );
 CREATE UNIQUE INDEX IF NOT EXISTS uniqueplaces ON coordinates ( instance,
                                                                 name,
                                                               );

 CREATE TABLE types ( id          INTEGER,
                      name        TEXT,
		      displayname TEXT,

		      PRIMARY KEY ( id )
		    );

=cut

__DATA__

@@ index.html.ep
% layout 'default';
% title "$instance Places";
<h1><%= $instance %> Places</h1>
<table id="coordinates" class="display">
    <thead>
        <tr>
            <th>Name</th>
            <th>Type</th>
            <th>X</th>
            <th>Y</th>
            <th>Z</th>
            <th>Actions</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>Name</td>
            <td>Type</td>
            <td>X</td>
            <td>Y</td>
            <td>Z</td>
        </tr>
    </tbody>
</table>
<br>
<form id="newcoord" method="post">
  <div id="messages" style="display:none;">No message</div>
  <fieldset>
    <legend>Add a new location</legend>
    <div>
      <input name="name" type="text" />
      <label for="name">Name</label>
    </div>
    <div>
      <select name="type">
        <option value="">Pick One</option>
        <option value="Village">Village</option>
        <option value="Station">Subway/Train Station</option>
        <option value="Public Hut">Public and "Rest Weary Traveler" hut</option>
	<option value="House">Private House</option>
        <option value="Temple">Fortress, Mansion, or Temple</option>
        <option value="Other">Other</option>
      </select>
      <label for="type">Type</label>
    </div>
    <div class="coordinates">
      <p>Coordinates:</p>
      <div>
        <input name="x" type="text" />
        <label for="x">X</label>
      </div>
      <div>
        <input name="y" type="text" />
        <label for="y">Y</label>
        (optional)
      </div>
      <div>
        <input name="z" type="text" />
        <label for="z">Z</label>
      </div>
    </div>
    <input type="submit" value="Submit">
  </fieldset>
</form>
<script>
'use strict';

var controller = {
  addurl   : function () { return controller.baseurl() + '/add' },
  baseurl  : function () {
               let regex   = new RegExp( /([^\?]+)/ ),
                   results = regex.exec( window.location.href );

                let url = '';

                if ( !results || !results[1] )
                  url = window.location.href;
                else
                  url = results[1];

                return url;
             },
  dataurl  : function () { return controller.baseurl() + '/data' },
  deleteplace : function (node) {
                  let data = controller.table.row( $(node).parents('tr') ).data();
                  let url = [ controller.baseurl(),
                              'del',
                              encodeURIComponent( data.name )
                            ].join( '/' );
                  $.ajax({ url    : url,
                           method : 'DELETE'
                         }).done(function(data){
                           controller.table.ajax.reload();
                         }).fail(function(jqxhr){
                           $("#messages").text( jqxhr.responseJSON.message ).show();
                         });
  },
  instance : function () {
               let url = controller.baseurl();

               let regex   = new RegExp( /([^\/]+)\/?$/ ),
                   results = regex.exec( url );

               return results[1];
             },
  init :     function () {
               $(document).ready( function () {
                   controller.table = $('#coordinates').DataTable({
                     ajax    : controller.dataurl(),
                     columns : [ { "data" : "name" },
                                 { "data" : "type" },
                                 { "data" : "x" },
                                 { "data" : "y" },
                                 { "data" : "z" },
                                 { "data" : null, "targets" : -1, "defaultContent" : "<button onclick='controller.deleteplace(this)'>Delete</button>" }
                               ],
                     dom     : '<"top"fl>rt<"bottom"ip>',
                   });

                   $( '#newcoord' ).on( 'submit', function ( event ) {
                     let jqxhr = $.post( controller.addurl(), $(this).serialize() )
                                  .done(function(data){
                                          controller.table.ajax.reload();
                                          $("#newcoord")[0].reset();
                                      })
                                  .fail(function(jqxhr){
                                          $("#messages").text( jqxhr.responseJSON.message ).show();
                                      });

                     event.preventDefault();
                   });
               });
             }
};

controller.init();
</script>

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head>
    <title><%= title %></title>
    <link rel="stylesheet" type="text/css" href="https://cdn.datatables.net/1.10.20/css/jquery.dataTables.css">
    <script type="text/javascript" charset="utf8" src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.4.1/jquery.min.js"></script>
    <script type="text/javascript" charset="utf8" src="https://cdn.datatables.net/1.10.20/js/jquery.dataTables.js"></script>
    <style>
    body {
        background-color: #fff;
    }
    form#newcoord fieldset,
    form#newcoord fieldset legend {
        background-color: #eee;
    }
    form#newcoord fieldset legend {
        border: solid 1px #777;
    }
    form#newcoord label {
        width:5em;
        float:left;
    }
    div.coordinates div {
        clear: both;
    }
    div.coordinates div label {
        width:3em;
        float:left;
    }
    div.coordinates div input {
    	width:3em;
    }
    div#messages {
        font-weight: bold;
    }
    table#coordinates th,
    table#coordinates td {
        text-align: left;
    }
    div#coordinates_length {
        float:right;
    }
    div#coordinates_filter {
        float: left;
        padding-right: 5em;
    }
    div#coordinates_info {
        padding-left: 2em;
    }
    </style>
  </head>
  <body><%= content %></body>
</html>

