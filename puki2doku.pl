#!/usr/bin/perl
#*****************************************************************************
# PukiWiki => DokuWiki data convertor
#
# Usage: puki2doku.pl -s pukiwiki/wiki -d dokuwiki/data/page
#                     [-S/--font-size]
#                     [-C/--font-color]
#                     [-I/--indexmenu]
#                     [-N/--ignore-unknown-macro]
#
#*****************************************************************************
use strict;
use warnings;
use utf8;
use Encode;
use File::Basename;
use File::Copy;
use File::Path;
use IO::File;
use Getopt::Long qw(:config no_ignore_case bundling);

# ＿・ と全角数字は記号扱いじゃない
my @KIGO_ARRAY = (
 '、',
 '。',
 '／',
 '　',
 '！',
 '＃',
 '＄',
 '＆',
 '＋',
 '（',
 '）',
 '＝',
 '＊',
 '「',
 '」',
 '『',
 '』',
 '＠',
 '【',
 '】',
 '―', # dash
 '‐', # hypen, minus
 '～', # wave dash
);
my $KIGO_STR = join("", @KIGO_ARRAY);

my $verbose;
my $use_font_color_plugin;
my $use_font_size_plugin;
my $use_indexmenu_plugin;
my $dst_dir = ".";
my $decode_mode;
my $attach_file_mode;
my $src_dir = ".";
my $ignore_unknown_macro;

my %smiles = (
  smile    => ' :-) ',
  bigsmile => ' LOL ',
  huh      => ' :-P ',
  oh       => ' :-/ ',
  wink     => ' ;-) ',
  sad      => ' :-( ',
  worried  => ' :-| ',
);

GetOptions("verbose|v"     => \$verbose,
           "font-color|C"  => \$use_font_color_plugin,
           "font-size|S"   => \$use_font_size_plugin,
           "indexmenu|I"   => \$use_indexmenu_plugin,
           "dst-dir|d=s"   => \$dst_dir,
           "decode|D"      => \$decode_mode,
           "attach|A"      => \$attach_file_mode,
           "src-dir|s=s"   => \$src_dir,
           "help|h"        => \&usage,
           "ignore-unknown-macro|N" => \$ignore_unknown_macro,
) || usage();

sub usage {
    print "Usage: $0 [-v] [-s dir] [-d dir] *.txt\n";
    print "       [--font-color/-C]\n";
    print "       [--font-size/-S]\n";
    print "       [--indexmenu/-I]\n";
    print "       [--ignore-unknown-macro/-N]\n";
    print "       [--decode/-D]\n";
    print "       [--attach/-A]\n";
    exit 1;
}

if ($decode_mode) {
    while (<>) {
        print $_;
        s/[\r\n]+$//;
        print encode("utf8", decode("euc-jp", pukiwiki_filename_decode($_))),"\n";
    }
    exit;
}

if (! -d $dst_dir) {
    warn "$dst_dir is not exist\n";
    exit 2;
}
elsif (! -w $dst_dir) {
    warn "$dst_dir is not writable\n";
    exit 3;
}

#-----------------------------------------------------------------------------

chdir($src_dir) || die "can't chdir $src_dir: $!";
my $d;
opendir($d, ".") || die "can't opendir: $src_dir: $!";

if ($attach_file_mode) {
    while (my $file = readdir($d)) {
        next if (-d $file || $file =~ /\.log$/ || $file eq "index.html" || $file eq ".htaccess");
        print $file,"\n" if ($verbose);
        copy_attach_file($file);
    }
}
else {
    while (my $file = readdir($d)) {
        next if (-d $file || $file !~ /\.txt$/);
        print $file,"\n" if ($verbose);
        convert_file($file);
    }
}

closedir($d);

#-----------------------------------------------------------------------------

sub copy_attach_file {
    my ($src_file) = @_;

    my $src_filename = basename($src_file);

    # {full_pagename}_{attached_filename} (pagename には / を含む)
    my ($full_pagename, $attached_filename) = split(/_/, $src_filename, 2);

    my $dokuwiki_subdir = convert_filename($full_pagename);
    my $dokuwiki_filename = convert_filename($attached_filename);

    my $media_dst_dir = join("/", $dst_dir, $dokuwiki_subdir);
    if (! -d $media_dst_dir) {
        mkpath($media_dst_dir) || die "can't mkdir $media_dst_dir: $!";
    }

    my $dst_file = join("/", $media_dst_dir, $dokuwiki_filename);

    printf "%s => %s\n", encode("utf8", $src_file), encode("utf8", $dst_file) if ($verbose);

    copy($src_file, $dst_file);
}

sub convert_file {
    my ($src_file) = @_;

    my $in_subdir = 0;
    my $last_line = "";

    my $r = new IO::File $src_file, "r";

    my $dokuwiki_filename = convert_filename($src_file);
    if ($dokuwiki_filename =~ /\//) {
        $in_subdir = 1;
    }

    # 小文字にしたり、記号を変換してないページ名
    my $pagename = decode("euc-jp", pukiwiki_filename_decode($src_file));

    return if ($pagename =~ /^:/); # 特殊ファイル

    $pagename =~ s/\.txt//;
    $pagename =~ s/\//:/g; # namespace の区切りは / ではなく :

    my $doku_file = sprintf "%s/%s",
                            $dst_dir,
                            $dokuwiki_filename;

    my $doku_file_dir = dirname($doku_file);
    if (! -d $doku_file_dir) {
        mkpath($doku_file_dir);
    }

    my $pre = 0;
    my $prettify = 0;
    my @sp_buf = (); # #contents

    my @doku_lines = ();

    while (my $line = <$r>) {
        $line = decode("euc-jp", $line);
        $line =~ s/[\r\n]+$//;

        # ----
        # #contents
        if ($line eq "----" && scalar(@sp_buf) == 0) {
            push @sp_buf, $line;
            next;
        }
        elsif ($line eq "----" && scalar(@sp_buf) == 2) {
            @sp_buf = ();
            next;
        }
        elsif ($line eq "#contents" && scalar(@sp_buf) == 1) {
            push @sp_buf, $line;
            next;
        }
        else {
            foreach (@sp_buf) {
                push @doku_lines, $_ . "\n";
            }
            @sp_buf = ();
        }
        # ----


        if ($use_indexmenu_plugin) {
            $line =~ s/^#ls2?\((.*)\).*$/convert_ls_indexmenu($pagename, $1)/e;
            $line =~ s/^#ls2?$/convert_ls_indexmenu($pagename)/e;
        }

        # prettify etention
        if ($line =~ /^#prettify{{/) {
            push @doku_lines, "<code>\n" if (! $pre);
            $prettify = 1;
            next;
        }
        elsif ($prettify) {
            if ($line =~ /^\}\}/) {
                push @doku_lines, "</code>\n";
                $prettify = 0;
            }
            else {
                push @doku_lines, $line . "\n";
            }
            next;
        }

        if ($line =~ s/^\x20// || $line =~ /^\t/) {
            if (! $pre) {
                if (scalar(@doku_lines) && $doku_lines[-1] =~ /^\s+\-/) {
                    $doku_lines[-1] =~ s/\n$//;
                }
                push @doku_lines, "<code>\n";
            }
            push @doku_lines, $line . "\n";
            $pre = 1;
            next;
        }
        elsif ($pre) {
            push @doku_lines, "</code>\n";
            $pre = 0;
        }

        if ($line =~ /^\-+$/) {
            push @doku_lines, $line . "\n";
            next;
        }

        # ref
        $line =~ s/\&ref\((.+?)\);/convert_ref($pagename, $1)/ge;
        $line =~ s/#ref\((.+?)\)/convert_ref($pagename, $1)/ge;

        next if ($line =~ /^#/ && $ignore_unknown_macro);

        # definitions
        $line =~ s/^:(.*?)\|(.*)$/  = $1 : $2/;

        # 装飾を削る (2回なのは入れ子対応、3回やっとく？)
        $line =~ s/\&(\w+)\(([^\(\)]+?)\){([^\{]*?)};/strip_decoration($1, $2, $3)/ge;
        $line =~ s/\&(\w+)\(([^\(\)]+?)\){([^\{]*?)};/strip_decoration($1, $2, $3)/ge;

        # 改行置換
        $line =~ s/~$/\\\\/;
        $line =~ s/\&br;/\\\\ /g;

        # italic
        $line =~ s#'''(.+?)'''#//$1//#g;

        # bold
        $line =~ s/''(.+?)''/\*\*$1\*\*/g;

        # del
        $line =~ s#\%\%(.+?)\%\%#<del>$1</del>#g;

        # escape
        $line =~ s#(?:^|[^:])(//)#%%$1%%#g;

        # heading
        $line =~ s/^\*\s*([^\*].*?)\[#.*$/heading(6, $1)/e;
        $line =~ s/^\*{2}\s*([^\*].*?)\[#.*$/heading(5, $1)/e;
        $line =~ s/^\*{3}\s*([^\*].*?)\[#.*$/heading(4, $1)/e;
        $line =~ s/^\*{4}\s*([^\*].*?)\[#.*$/heading(3, $1)/e;
        $line =~ s/^\*{5}\s*([^\*].*?)\[#.*$/heading(2, $1)/e;

        # list
        $line =~ s/^(\++)\s*([^\-]*.*)$/convert_ol($1, $2)/e;
        $line =~ s/^(\-+)\s*([^\-]*.*)$/convert_ul($1, $2)/e;

        # smile
        $line =~ s/\&(\w+);/smile($1)/ge;

        # table
        if ($line =~ /^\|/) {
            $line = convert_table($line);
        }
        else {
            # TODO
            # reset format
        }

        # table は直前の行が空行じゃないとダメっぽい
        if (scalar(@doku_lines)) {
            if ($line =~ /^[\^\|]/
             && $doku_lines[-1] !~ /^[\^\|]/ && $doku_lines[-1] ne "") {
                push @doku_lines, "\n";
            }
        }

        # link (中に|を含むので table より後に処理)
        $line =~ s/\[\[(.+?)\]\]/convert_link($1, $in_subdir)/ge;

        # email link (mailto)
        $line =~ s/(^|[^\[])([a-zA-Z0-9\._\-]+\@[a-zA-Z0-9\.]+\.[a-zA-Z0-9]+)([^\]]|$)/$1\[\[$2\]\]$3/g;

        $line =~ s/\&nbsp;/\x20/g;

        if ($line =~ /\\\\$/) {
            push @doku_lines, $line . " ";
        }
        else {
            push @doku_lines, $line . "\n";
        }
    }

    push @doku_lines, "</code>\n" if ($pre);

    $r->close;

    my $w = new IO::File $doku_file, "w";
    if (! defined $w) {
        warn "can't open $doku_file: $!";
        return;
    }
    foreach my $line (@doku_lines) {
        print $w encode("utf8", $line);
    }
    $w->close;

    # copy last modified
    system("/bin/touch", "-r", $src_file, $doku_file);
}

sub heading {
    my ($n, $str) = @_;

    if ($str =~ /\[\[(.*)\]\]/) {
        my $link = $1;
        $link =~ s/^.*[>\|]//;
        $str = $link;
    }
    return "=" x $n . " " . $str . " " . "=" x $n;
}

sub convert_ls_indexmenu {
    my ($src_pagename, $namespace) = @_;

    $namespace = "" if (! $namespace);
    $namespace =~ s/\//:/g;
    $namespace = $src_pagename if (! $namespace);

    if ($namespace) {
        return "{{indexmenu>" . $namespace . "|tsort}}"
    }
    else {
        return "{{indexmenu>.|tsort}}"
    }
}

sub convert_table {
    my ($line, $format) = @_;

    my $is_header = 0;
    my $is_format = 0;
    my $is_footer = 0;

    if ($line =~ s/\|h$/|/) {
        $is_header = 1;
    }
    elsif ($line =~ s/\|c$/|/) {
        # TODO
        $is_format = 1;
        return "";
    }
    elsif ($line =~ s/\|f$/|/) {
        $is_footer = 1;
        return "";
    }

    my @cols = split(/\s*\|\s*/, $line);
    shift @cols;

    my $new_line = "";

    my $span = 0;

    foreach my $col (@cols) {
        my $pos = "";
        if ($span == 0) {
            $new_line .= ($is_header) ? '^' : '|';
        }

        while ($col =~ s/^(LEFT|CENTER|RIGHT|COLOR\(.*?\)|BGCOLOR\(.*?\)|SIZE\(.*?\))://) {
            if ($1 eq "LEFT" || $1 eq "CENTER" || $1 eq "RIGHT") {
                $pos = $1;
            }
            $pos = "CENTER" if ($is_header);
        }

        if ($col eq ">") {
            ++$span;
            next;
        }
        elsif ($col =~ /^\s*~\s*$/) {
            $col = " ::: ";
        }
        elsif ($col eq "") {
            $col = " ";
        }

        if ($pos eq "LEFT") {
            $col .= "  ";
        }
        elsif ($pos eq "CENTER") {
            $col = "  " . $col . "  ";
        }
        elsif ($pos eq "RIGHT") {
            $col = "  " . $col;
        }

        $new_line .= $col;
        if ($col ne "" && $span) {
            $new_line .= "|" x $span;
            $span = 0;
        }
    }
    $new_line .= ($is_header) ? '^' : '|';

    return $new_line;
}

sub smile {
    my ($str) = @_;

    if (exists $smiles{$str}) {
        return $smiles{$str};
    }
    else {
        return sprintf '&%s;', $str;
    }
}

sub convert_ol {
    my ($mark, $str) = @_;

    my $space = "  " x length($mark);

    return $space . "- " . $str;
}

sub convert_ul {
    my ($mark, $str) = @_;

    my $space = "  " x length($mark);

    return $space . "* " . $str;
}

sub convert_link {
    my ($str, $in_subdir) = @_;

    my $text;
    my $url;

    # [[text>url]]
    if ($str =~ />/) {
        ($text, $url) = split(/>/, $str, 2);
        $url =~ s/\//:/g if ($url !~ /^http/);
    }

    # [[text:url]]
    elsif ($str !~ /^http/ && $str =~ /:/) {
        ($text, $url) = split(/:/, $str, 2);
        $url =~ s/\//:/g if ($url !~ /^http/);
    }

    # [[Internal/Name]]
    elsif ($str !~ /^http/ && $str =~ /\//) {
        $str =~ s/\//:/g;
    }

    # [[WikiName]], [[http://....]]
    else {
        $url = $str if ($str =~ /^http/);
        $str = "start" if ($str eq "FrontPage");
    }

    if (! $url) {
        if ($in_subdir) {
            return "[[:" . $str . "]]";
        }
        else {
            return "[[" . $str . "]]";
        }
    }
    elsif ($url && ! $text) {
        return "[[" . $url . "]]";
    }
    else {
        return "[[" . join("|", $url, $text) . "]]";
    }
}

sub convert_ref {
    my ($src_pagename, $str) = @_;

    my ($link_to, $option) = split(/,/, $str, 2);

    if ($link_to =~ /^http/) {
        return sprintf "[[%s|{{%s}}]]", $link_to, $link_to;
    }
    else {
        return sprintf "{{%s:%s}}", $src_pagename, $link_to;
    }
}

sub convert_filename {
    my ($filename) = @_;

    my $decoded = decode("euc-jp", pukiwiki_filename_decode($filename));

    print encode("utf8", $decoded),"\n" if ($verbose);


    # マルチバイト => ascii の正規化 結果 _ になるので _ に置換
    $decoded =~ s/[$KIGO_STR]+/_/g;

    # 半角記号のうち .-/ 以外を _ に置換(連続するものは1つにまとめる)
    $decoded =~ s/[\x20-\x2c\x3a-\x40\x5b-\x60\x7b-\x7e]+/_/g;

    # 末尾の _ は削る
    $decoded =~ s/_+.txt$/.txt/;
    # ディレクトリの末尾からも削る
    $decoded =~ s#_+/#/#g;

    # アルファベットは小文字に置換
    $decoded =~ tr/[A-Z]/[a-z]/;

    # .-/a-z 以外を url encode
    my $dokuwiki_name = dokuwiki_url_encode($decoded);

    return encode("utf8", $dokuwiki_name);
}

sub pukiwiki_filename_decode {
    my ($str) = @_;

    $str =~ s/([0-9A-F]{2})/pack("C",hex($1))/ge;

    if ($str eq "FrontPage.txt") {
        $str = "start.txt";
    }

    return $str;
}

sub dokuwiki_url_encode {
    my ($str) = @_;
    $str = encode("utf8", $str);
    $str =~ s/([^a-zA-Z0-9_.\-\/])/uc sprintf("%%%02x",ord($1))/eg;
    return decode("utf8", $str);
}

sub strip_decoration {
    my ($type, $attr, $str) = @_;

    if ($type eq "size" && $use_font_size_plugin) {
        if ($attr > 20) {
            return sprintf qq(####%s####), $str;
        }
        else {
            return sprintf qq(##%s##), $str;
        }
    }
    elsif ($type eq "color" && $use_font_color_plugin) {
        return sprintf qq(<color %s/white>%s</color>), $attr, $str;
    }
    else {
        return $str;
    }
}
