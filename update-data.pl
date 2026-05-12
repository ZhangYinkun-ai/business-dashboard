#!/usr/bin/perl
# ============================================================
# 商家寄件业务数据更新 - Perl 版本
# ============================================================

use strict;
use warnings;
use JSON::PP;
use Time::Piece;
use File::Copy;
use Encode qw(decode encode);

# ============================================================
# 配置
# ============================================================
my $script_dir = $0;
$script_dir =~ s|[\\/][^\\/]+$||;
$script_dir = '.' if !$script_dir || $script_dir eq $0;
my $data_json = "$script_dir/src/data.json";

# ============================================================
# 解析命令行
# ============================================================
my $csv_path = '';
for my $i (0..$#ARGV) {
    if ($ARGV[$i] eq '--csv' && $i < $#ARGV) {
        $csv_path = $ARGV[$i+1];
    } elsif ($ARGV[$i] =~ /\.csv$/i) {
        $csv_path = $ARGV[$i];
    }
}

# ============================================================
# 读取数据
# ============================================================
my @lines;
if ($csv_path && -f $csv_path) {
    open(my $fh, '<:raw', $csv_path) or die "Cannot open $csv_path: $!";
    while (my $l = <$fh>) {
        push @lines, decode('utf8', $l);
    }
    close($fh);
    print "  Reading CSV: $csv_path\n";
} else {
    while (my $l = <STDIN>) {
        push @lines, decode('utf8', $l);
    }
    print "  Reading from stdin\n";
}

# ============================================================
# 承运商名称映射
# ============================================================
my %carrier_map = (
    decode('utf8', '中通')     => decode('utf8', '中通快递'),
    decode('utf8', '中通快递') => decode('utf8', '中通快递'),
    decode('utf8', '圆通')     => decode('utf8', '圆通速递'),
    decode('utf8', '圆通速递') => decode('utf8', '圆通速递'),
    decode('utf8', '申通')     => decode('utf8', '申通快递'),
    decode('utf8', '申通快递') => decode('utf8', '申通快递'),
    decode('utf8', '韵达')     => decode('utf8', '韵达快递'),
    decode('utf8', '韵达速递') => decode('utf8', '韵达快递'),
    decode('utf8', '韵达快递') => decode('utf8', '韵达快递'),
    decode('utf8', '极兔')     => decode('utf8', '极兔速递'),
    decode('utf8', '极兔速递') => decode('utf8', '极兔速递'),
    decode('utf8', '菜鸟速递') => decode('utf8', '菜鸟速递'),
    decode('utf8', '邮政')     => decode('utf8', '邮政电商标快'),
    decode('utf8', '邮政快递') => decode('utf8', '邮政电商标快'),
    decode('utf8', '邮政标快') => decode('utf8', '邮政电商标快'),
    decode('utf8', '邮政电商标快') => decode('utf8', '邮政电商标快'),
    decode('utf8', 'EMS')      => decode('utf8', '邮政电商标快'),
    decode('utf8', '顺丰')     => decode('utf8', '顺丰速运'),
    decode('utf8', '顺丰速运') => decode('utf8', '顺丰速运'),
    decode('utf8', '顺丰快递') => decode('utf8', '顺丰速运'),
);

my %is_merchant = map { (decode('utf8', $_) => 1) }
    qw(中通快递 圆通速递 申通快递 韵达快递 极兔速递 顺丰速运 邮政电商标快 菜鸟速递);

# ============================================================
# 解析数据
# ============================================================
my %carrier_data;

for my $line (@lines) {
    $line =~ s/^\s+|\s+$//g;
    next if !$line;
    next if $line =~ /^[\+\-]/;
    next if $line =~ /^metric/i;
    next if $line =~ /^carrier/i;
    
    # Remove pipe characters
    $line =~ s/^\s*\|\s*//;
    $line =~ s/\s*\|\s*$//;
    
    # Split by tab or pipe
    my @cols;
    if ($line =~ /\|/) {
        @cols = map { s/^\s+|\s+$//gr } split(/\s*\|\s*/, $line);
    } elsif ($line =~ /\t/) {
        @cols = map { s/^\s+|\s+$//gr } split(/\t/, $line);
    } else {
        @cols = map { s/^\s+|\s+$//gr } split(/,/, $line);
    }
    
    next if scalar(@cols) < 3;
    
    my $metric_type = $cols[0];
    my $carrier_name = $cols[1];
    my $daily_avg = $cols[2];
    $daily_avg =~ s/[^\d\.\-]//g;
    $daily_avg = 0 if !$daily_avg || $daily_avg eq '-';
    
    # Map carrier name
    my $mapped = '';
    if (exists $carrier_map{$carrier_name}) {
        $mapped = $carrier_map{$carrier_name};
    }
    next if !$mapped;
    next if !$is_merchant{$mapped};
    
    # Initialize
    if (!exists $carrier_data{$mapped}) {
        $carrier_data{$mapped} = {
            fy26DailyAvg => 0,
            tMinus1Volume => 0,
            monthlyDailyAvg => {},
        };
    }
    
    # Store data
    if ($metric_type eq decode('utf8', 'FY26日均')) {
        $carrier_data{$mapped}{fy26DailyAvg} = int($daily_avg);
        print "  " . encode('utf8', "$mapped: FY26 = $daily_avg") . "\n";
    } elsif ($metric_type =~ /^T-1/) {
        $carrier_data{$mapped}{tMinus1Volume} = int($daily_avg);
        print "  " . encode('utf8', "$mapped: T-1 = $daily_avg") . "\n";
    } elsif ($metric_type =~ /(\d+)(\x{6708})/) {  # \x{6708} is Unicode for 月
        my $month = int($1);
        if ($month >= 1 && $month <= 12) {
            $carrier_data{$mapped}{monthlyDailyAvg}{$month} = int($daily_avg);
            print "  " . encode('utf8', "$mapped: ${month}月 = $daily_avg") . "\n";
        }
    }
}

my $count = scalar(keys %carrier_data);
print "  Parsed $count carriers\n";

# ============================================================
# 更新 data.json
# ============================================================
if (!-f $data_json) {
    die "data.json not found: $data_json\n";
}

# Read JSON
open(my $jfh, '<:raw', $data_json) or die "Cannot read $data_json: $!";
my $json_text = decode('utf8', do { local $/; <$jfh> });
close($jfh);

my $json = JSON::PP->new->canonical;
my $data = $json->decode($json_text);

# Update timestamp
my $t = gmtime();
$data->{lastUpdated} = $t->strftime('%Y-%m-%dT%H:%M:%S+00:00');

# Update carriers
my $updated = 0;
for my $carrier (@{$data->{carriers}}) {
    my $name = $carrier->{name};
    if (exists $carrier_data{$name}) {
        my $odps = $carrier_data{$name};
        $carrier->{fy26DailyAvg} = $odps->{fy26DailyAvg};
        $carrier->{tMinus1Volume} = $odps->{tMinus1Volume};
        
        # Merge monthly data
        my %monthly = %{$carrier->{monthlyDailyAvg} || {}};
        for my $m (keys %{$odps->{monthlyDailyAvg}}) {
            $monthly{$m} = $odps->{monthlyDailyAvg}{$m};
        }
        $carrier->{monthlyDailyAvg} = \%monthly;
        
        $updated++;
    }
}

print "  Updated $updated carriers\n";

# Backup
copy($data_json, "$data_json.bak");

# Save
my $output = $json->pretty->encode($data);
open(my $ofh, '>:raw', $data_json) or die "Cannot write $data_json: $!";
print $ofh encode('utf8', $output);
close($ofh);

print "  data.json updated\n";
