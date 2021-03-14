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
                                                                name
                                                              );

CREATE TABLE types ( id          INTEGER,
                     name        TEXT,
                     displayname TEXT,

                     PRIMARY KEY ( id )
                   );

