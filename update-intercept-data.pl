#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use JSON::PP;
use Time::Piece;
use File::Copy;
use Encode qw(decode encode);

my $script_dir = $0;
$script_dir =~ s|[\\/][^\\/]+$||;
$script_dir = '.' if !$script_dir || $script_dir eq $0;
my $data_json = "$script_dir/src/data.json";
my $csv_path = "$script_dir/scripts/intercept-data-utf8.csv";

# 承运商映射（use utf8 下字面量已是 Unicode 字符）
my %carrier_map = (
    '中通'     => '中通快递',
    '圆通'     => '圆通速递',
    '申通'     => '申通快递',
    '韵达'     => '韵达快递',
    '极兔'     => '极兔速递',
    '京东快递' => '京东快递',
    '邮政'     => '邮政电商标快',
);

my %is_intercept = map { ($_ => 1) }
    qw(中通快递 圆通速递 申通快递 韵达快递 极兔速递 京东快递 邮政电商标快);

# 读取快递拦截数据
my %intercept_data;

open(my $cfh, '<:raw', $csv_path) or die "Cannot open $csv_path: $!";
while (my $l = <$cfh>) {
    my $line = decode('utf8', $l);
    $line =~ s/^\s+|\s+$//g;
    next if !$line;
    next if $line =~ /^[\+\-]/;
    next if $line =~ /^time/i;
    
    $line =~ s/^\s*\|\s*//;
    $line =~ s/\s*\|\s*$//;
    
    my @cols = map { s/^\s+|\s+$//gr } split(/\s*\|\s*/, $line);
    next if scalar(@cols) < 3;
    
    my $time_period = $cols[0];
    my $cp_name = $cols[1];
    my $mail_cnt = $cols[2];
    $mail_cnt =~ s/[^\d\.\-]//g;
    $mail_cnt = 0 if !$mail_cnt || $mail_cnt eq '-';
    
    next if $cp_name eq '汇总';
    
    my $mapped = '';
    if (exists $carrier_map{$cp_name}) {
        $mapped = $carrier_map{$cp_name};
    }
    next if !$mapped;
    next if !$is_intercept{$mapped};
    
    if (!exists $intercept_data{$mapped}) {
        $intercept_data{$mapped} = {
            fy26DailyAvg => 0,
            tMinus1Volume => 0,
            monthlyDailyAvg => {},
        };
    }
    
    if ($time_period =~ /^FY26/) {
        $intercept_data{$mapped}{fy26DailyAvg} = int($mail_cnt);
        print "  " . encode('utf8', "$mapped: FY26 = $mail_cnt") . "\n";
    } elsif ($time_period =~ /^T-1/) {
        $intercept_data{$mapped}{tMinus1Volume} = int($mail_cnt);
        print "  " . encode('utf8', "$mapped: T-1 = $mail_cnt") . "\n";
    } elsif ($time_period =~ /(\d{4})\x{5e74}(\d{1,2})\x{6708}/) {
        my $month = int($2);
        if ($month >= 1 && $month <= 12) {
            $intercept_data{$mapped}{monthlyDailyAvg}{$month} = int($mail_cnt);
            print "  " . encode('utf8', "$mapped: ${month}\x{6708} = $mail_cnt") . "\n";
        }
    }
}
close($cfh);

my $count = scalar(keys %intercept_data);
print "  Parsed $count carriers for 快递拦截\n";

# 读取 data.json（字节模式）
open(my $jfh, '<:raw', $data_json) or die "Cannot read $data_json: $!";
my $json_bytes = do { local $/; <$jfh> };
close($jfh);

my $json = JSON::PP->new->canonical->utf8;
my $data = $json->decode($json_bytes);

# 更新 timestamp
my $t = gmtime();
$data->{lastUpdated} = $t->strftime('%Y-%m-%dT%H:%M:%S+00:00');

# 更新快递拦截数据
my $updated = 0;
for my $carrier (@{$data->{carriers}}) {
    my $name = $carrier->{name};
    if (exists $intercept_data{$name}) {
        $carrier->{projectData}{'快递拦截'} = $intercept_data{$name};
        $updated++;
    }
}

print "  Updated $updated carriers with 快递拦截 data\n";

# 保存
my $output = $json->pretty->encode($data);
open(my $ofh, '>:raw', $data_json) or die "Cannot write $data_json: $!";
print $ofh $output;
close($ofh);

print "  data.json updated\n";
