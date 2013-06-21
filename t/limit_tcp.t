use warnings;
use strict;

use Test::More;
use Time::Local;

BEGIN { use FindBin; chdir($FindBin::Bin); }


use lib 'lib';
use File::Path;
use Test::Nginx;


my $NGINX = defined $ENV{TEST_NGINX_BINARY} ? $ENV{TEST_NGINX_BINARY}
        : '../nginx/objs/nginx';
my $t = Test::Nginx->new()->plan(22);

sub mhttp_get($;$;$;%) {
    my ($url, $port, %extra) = @_;
    return mhttp(<<EOF, $port, %extra);
GET $url HTTP/1.0
Host: localhost

EOF
}

sub mrun($;$) {
    my ($self, $conf) = @_;

    my $testdir = $self->{_testdir};

    if (defined $conf) {
        my $c = `cat $conf`;
        $self->write_file_expand('nginx.conf', $c);
    }

    my $pid = fork();
    die "Unable to fork(): $!\n" unless defined $pid;

    if ($pid == 0) {
        my @globals = $self->{_test_globals} ?
            () : ('-g', "pid $testdir/nginx.pid; "
                  . "error_log $testdir/error.log debug;");
        exec($NGINX, '-c', "$testdir/nginx.conf", '-p', "$testdir",
             @globals) or die "Unable to exec(): $!\n";
    }

    # wait for nginx to start

    $self->waitforfile("$testdir/nginx.pid")
        or die "Can't start nginx";

    $self->{_started} = 1;
    return $self;
}

###############################################################################

select STDERR; $| = 1;
select STDOUT; $| = 1;

warn "your test dir is ".$t->testdir();

$t->write_file_expand('nginx.conf', <<'EOF');

%%TEST_GLOBALS%%

daemon off;

worker_processes auto;

events {
    accept_mutex off;
}


limit_tcp 8088 rate=1r/s burst=1 nodelay;
limit_tcp 8089 rate=30r/m name=b:1M burst=100;


http {
    server {
        listen 8088;
        location / {
            echo 8088;
        }
    }

    server {
        listen 8089;
        location / {
            echo 8089;
        }
    }
}
EOF

mrun($t);

###############################################################################


like(mhttp_get('/', 8088), qr/8088/m, '2013-04-15 15:55:25');
like(mhttp_get('/', 8088), qr/8088/m, '2013-04-15 20:42:57');
unlike(mhttp_get('/', 8088), qr/8088/m, '2013-04-15 20:42:54');

like(mhttp_get('/', 8089), qr/8089/m, '2013-04-15 20:59:33');
unlike(mhttp_get('/', 8089), qr/8089/m, '2013-04-15 20:59:36');
sleep 2;
like(mhttp_get('/', 8089), qr/8089/m, '2013-04-16 00:26:08');



$t->stop();

##############################################################


$t->write_file_expand('nginx.conf', <<'EOF');

%%TEST_GLOBALS%%

daemon off;

worker_processes auto;

events {
    accept_mutex off;
}


limit_tcp 8088 rate=1r/s burst=1 nodelay;
limit_tcp 8089 rate=30r/m name=b:1M burst=100;
limit_tcp_allow 127.0.0.1/32;


http {
    server {
        listen 8088;
        location / {
            echo 8088;
        }
    }

    server {
        listen 8089;
        location / {
            echo 8089;
        }
    }
}
EOF

mrun($t);

###############################################################################


like(mhttp_get('/', 8088), qr/8088/m, '2013-04-15 15:55:25');
like(mhttp_get('/', 8088), qr/8088/m, '2013-04-16 00:27:27');
like(mhttp_get('/', 8088), qr/8088/m, '2013-04-16 00:27:29');
like(mhttp_get('/', 8088), qr/8088/m, '2013-04-16 00:27:32');

like(mhttp_get('/', 8089), qr/8089/m, '2013-04-16 00:27:35');
like(mhttp_get('/', 8089), qr/8089/m, '2013-04-16 00:27:37');
like(mhttp_get('/', 8089), qr/8089/m, '2013-04-16 00:27:41');
like(mhttp_get('/', 8089), qr/8089/m, '2013-04-16 00:27:44');

$t->stop();

##############################################################################


$t->write_file_expand('nginx.conf', <<'EOF');

%%TEST_GLOBALS%%

daemon off;

worker_processes auto;

events {
    accept_mutex off;
}


limit_tcp 8088 rate=1r/s burst=1 nodelay;
limit_tcp 8089 rate=30r/m name=b:1M burst=100;
limit_tcp_deny 127.0.0.1/32;


http {
    server {
        listen 8088;
        location / {
            echo 8088;
        }
    }

    server {
        listen 8089;
        location / {
            echo 8089;
        }
    }
}
EOF

mrun($t);

###############################################################################


unlike(mhttp_get('/', 8088), qr/8088/m, '2013-04-16 00:28:31');
unlike(mhttp_get('/', 8088), qr/8088/m, '2013-04-16 00:28:33');
unlike(mhttp_get('/', 8088), qr/8088/m, '2013-04-16 00:28:35');
unlike(mhttp_get('/', 8088), qr/8088/m, '2013-04-16 00:28:37');

unlike(mhttp_get('/', 8089), qr/8089/m, '2013-04-16 00:28:40');
unlike(mhttp_get('/', 8089), qr/8089/m, '2013-04-16 00:28:42');
unlike(mhttp_get('/', 8089), qr/8089/m, '2013-04-16 00:28:44');
unlike(mhttp_get('/', 8089), qr/8089/m, '2013-04-16 00:27:46');

$t->stop();

##############################################################################


sub mhttp($;$;%) {
    my ($request, $port, %extra) = @_;
    my $reply;
    eval {
        local $SIG{ALRM} = sub { die "timeout\n" };
        local $SIG{PIPE} = sub { die "sigpipe\n" };
        alarm(2);
        my $s = IO::Socket::INET->new(
            Proto => "tcp",
            PeerAddr => "127.0.0.1:$port"
            );
        log_out($request);
        $s->print($request);
        local $/;
        select undef, undef, undef, $extra{sleep} if $extra{sleep};
        return '' if $extra{aborted};
        $reply = $s->getline();
        alarm(0);
    };
    alarm(0);
    if ($@) {
        log_in("died: $@");
        return undef;
    }
    log_in($reply);
    return $reply;
}
