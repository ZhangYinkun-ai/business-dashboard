#!/usr/bin/perl
# ============================================================
# 多项目业务数据更新 - 支持 projectData
# ============================================================

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
my $csv_path = "$script_dir/scripts/shsm-data-utf8.csv";

# ============================================================
# 承运商名称映射（送货上门口径）
# ============================================================
my %carrier_map = (
    '中通'     => '中通快递',
    '圆通'     => '圆通速递',
    '申通'     => '申通快递',
    '韵达'     => '韵达快递',
    '极兔速递' => '极兔速递',
    '顺丰'     => '顺丰速运',
    '丹鸟'     => '菜鸟速递',
);

my %is_shsm = map { ($_ => 1) }
    qw(中通快递 圆通速递 申通快递 韵达快递 极兔速递 顺丰速运 菜鸟速递);

# ============================================================
# 读取送货上门数据
# ============================================================
my %shsm_data;

open(my $cfh, '<:raw', $csv_path) or die "Cannot open $csv_path: $!";
while (my $l = <$cfh>) {
    my $line = decode('utf8', $l);
    $line =~ s/^\s+|\s+$//g;
    next if !$line;
    next if $line =~ /^[\+\-]/;
    next if $line =~ /^company/i;
    
    $line =~ s/^\s*\|\s*//;
    $line =~ s/\s*\|\s*$//;
    
    my @cols = map { s/^\s+|\s+$//gr } split(/\s*\|\s*/, $line);
    next if scalar(@cols) < 3;
    
    my $company_group = $cols[0];
    my $metric = $cols[1];
    my $val = $cols[2];
    $val =~ s/[^\d\.\-]//g;
    $val = 0 if !$val || $val eq '-';
    
    # Map carrier name
    my $mapped = '';
    if (exists $carrier_map{$company_group}) {
        $mapped = $carrier_map{$company_group};
    }
    next if !$mapped;
    next if !$is_shsm{$mapped};
    
    if (!exists $shsm_data{$mapped}) {
        $shsm_data{$mapped} = {
            fy26DailyAvg => 0,
            tMinus1Volume => 0,
            monthlyDailyAvg => {},
        };
    }
    
    if ($metric =~ /^FY26\x{65e5}\x{5747}/) {
        $shsm_data{$mapped}{fy26DailyAvg} = int($val);
        print "  " . encode('utf8', "$mapped: FY26 = $val") . "\n";
    } elsif ($metric =~ /^T-1/) {
        $shsm_data{$mapped}{tMinus1Volume} = int($val);
        print "  " . encode('utf8', "$mapped: T-1 = $val") . "\n";
    } elsif ($metric =~ /^(\d{4})(\d{2})/) {
        my $month = int($2);
        if ($month >= 1 && $month <= 12) {
            $shsm_data{$mapped}{monthlyDailyAvg}{$month} = int($val);
            print "  " . encode('utf8', "$mapped: ${month}\x{6708} = $val") . "\n";
        }
    }
}
close($cfh);

my $count = scalar(keys %shsm_data);
print "  Parsed $count carriers for 送货上门\n";

# ============================================================
# 读取并更新 data.json
# ============================================================
open(my $jfh, '<:raw', $data_json) or die "Cannot read $data_json: $!";
my $json_bytes = do { local $/; <$jfh> };
close($jfh);

my $json = JSON::PP->new->canonical->utf8;
my $data = $json->decode($json_bytes);

# Update timestamp
my $t = gmtime();
$data->{lastUpdated} = $t->strftime('%Y-%m-%dT%H:%M:%S+00:00');

# Migrate existing carrier data to projectData['商家寄件']
for my $carrier (@{$data->{carriers}}) {
    if (!exists $carrier->{projectData}) {
        $carrier->{projectData} = {};
    }
    
    # Migrate 商家寄件 data if not already migrated
    if (!exists $carrier->{projectData}{'商家寄件'}) {
        $carrier->{projectData}{'商家寄件'} = {
            fy26DailyAvg => $carrier->{fy26DailyAvg},
            tMinus1Volume => $carrier->{tMinus1Volume},
            monthlyDailyAvg => $carrier->{monthlyDailyAvg} // {},
        };
    }
    
    # Update 送货上门 data
    my $name = $carrier->{name};
    if (exists $shsm_data{$name}) {
        $carrier->{projectData}{'送货上门'} = $shsm_data{$name};
    }
}

# Update project-level data for 送货上门
for my $proj (@{$data->{projects}}) {
    if ($proj->{name} eq '送货上门') {
        # Calculate totals from carrier data
        my $total_fy26 = 0;
        my $total_t1 = 0;
        for my $carrier (@{$data->{carriers}}) {
            my $name = $carrier->{name};
            next unless $is_shsm{$name};
            next if $name eq '顺丰速运';
            next if $name eq '菜鸟速递';
            if (exists $carrier->{projectData}{'送货上门'}) {
                $total_fy26 += $carrier->{projectData}{'送货上门'}{fy26DailyAvg} // 0;
                $total_t1 += $carrier->{projectData}{'送货上门'}{tMinus1Volume} // 0;
            }
        }
        $proj->{fy26DailyAvg} = $total_fy26;
        $proj->{tMinus1Volume} = $total_t1;
        print "  送货上门 project totals: FY26=$total_fy26, T-1=$total_t1\n";
    }
}

print "  data.json updated with projectData\n";

# Backup
copy($data_json, "$data_json.bak2");

# Save
my $output = $json->pretty->encode($data);
open(my $ofh, '>:raw', $data_json) or die "Cannot write $data_json: $!";
print $ofh $output;
close($ofh);
