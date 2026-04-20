#!/usr/bin/perl -w
##***************************************************************************
# All rights reserved.
#
# Description:
#    Script to generate part of pad_ctrl.v codes file.
#
# Input      :
#   Config info via a config file.
#
# Output     :
#
# Author     : liang.zheng
#
#***************************************************************************/

    my $file_name;
    if($ARGV[0] eq ""){
        print "\n\terror! please choose a input filelist.....\n";
        print "\tex:\n\t\tram_update_to_aml_v02.pl file_name.l\n\n";
        exit();
    }else{
        $file_name = $ARGV[0];
    }

    open READ_FILE,"<$file_name" or die "Can't open $file_name\n";
    while(<READ_FILE>){
        chomp;
        my $x = $_;
        while(length($x)>0){

            my $y = substr($x,0,1);
            if   ($y eq "0"){print "0000";  $x = substr($x,1)}
            elsif($y eq "1"){print "0001";  $x = substr($x,1)}
            elsif($y eq "2"){print "0010";  $x = substr($x,1)}
            elsif($y eq "3"){print "0011";  $x = substr($x,1)}
            elsif($y eq "4"){print "0100";  $x = substr($x,1)}
            elsif($y eq "5"){print "0101";  $x = substr($x,1)}
            elsif($y eq "6"){print "0110";  $x = substr($x,1)}
            elsif($y eq "7"){print "0111";  $x = substr($x,1)}
            elsif($y eq "8"){print "1000";  $x = substr($x,1)}
            elsif($y eq "9"){print "1001";  $x = substr($x,1)}
            elsif($y eq "a"){print "1010";  $x = substr($x,1)}
            elsif($y eq "b"){print "1011";  $x = substr($x,1)}
            elsif($y eq "c"){print "1100";  $x = substr($x,1)}
            elsif($y eq "d"){print "1101";  $x = substr($x,1)}
            elsif($y eq "e"){print "1110";  $x = substr($x,1)}
            elsif($y eq "f"){print "1111";  $x = substr($x,1)}
            elsif($y eq "A"){print "1010";  $x = substr($x,1)}
            elsif($y eq "B"){print "1011";  $x = substr($x,1)}
            elsif($y eq "C"){print "1100";  $x = substr($x,1)}
            elsif($y eq "D"){print "1101";  $x = substr($x,1)}
            elsif($y eq "E"){print "1110";  $x = substr($x,1)}
            elsif($y eq "F"){print "1111";  $x = substr($x,1)}
            else            {print $y;      $x = substr($x,1)}
        }   
        print"\n";
    
    }close READ_FILE;
    
