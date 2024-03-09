#! /usr/bin/perl
    use strict;
    
    my $chip            = $ENV{chip} ;
    my $proj; if($chip=~/project_(\w+)/){$proj=$1}

    my $chip_core = "$chip/top/rtl/chip_core.v";

    my $flg=0;
    my $irq_wire;
    my @irq_list;
    open READ_FILE,"<$chip_core" or die "Can't open $chip_core\n";
    while(<READ_FILE>){
        chomp;
        if(/^\/\/.*/){next}
        s/\/\/.*//;       
        if(/wire.*irq_in\d+/){$flg=1}
        if($flg==1){$irq_wire.=$_}
        if(/;/ & $flg == 1){
            $flg=0;
            $irq_wire =~ s/\s//g;
            #print"$irq_wire\n";
            my @tmp = &process_irq($irq_wire);
            my $len = @tmp;
            if($len != 32){print"\n@tmp\n";die "Error! $irq_wire is not 32 bit width.\n";}
            push(@irq_list,\@tmp);
            $irq_wire = "";
            #exit;
        }
    }close READ_FILE;

    my $len = @irq_list;
 
    open WRITE_FILE,">${proj}_irq_source.csv" or die "Can't open ${proj}_irq_source.csv\n";
        for(my $i=$len-1;$i>=0;$i--){
            print WRITE_FILE "irq_in$i,";
        }
        print WRITE_FILE "\n";
        for(my $j=0;$j<32;$j++){
            for (my $i = 0;$i<$len;$i++){
                print WRITE_FILE "$irq_list[$i][$j],";
            }
            print WRITE_FILE "\n";
        }
        print WRITE_FILE "\n";
    close WRITE_FILE;

    print "\nBuild ${proj}_irq_source.csv\n\n";
    
    sub process_irq(){
        my $tmp = shift;
        $tmp =~s/.*=//;
        $tmp =~s/{//;
        $tmp =~s/}//;
        $tmp =~s/;//;
        #print"$tmp\n";
        my @list = split(/,/,$tmp);
        my @output;
        my $i;
        foreach(@list){
            if(/(\w+)\[(\d+)\:(\d+)]/){                
                for($i=$2;$i>=$3;$i--){
                    push(@output,"${1}\[$i\]");
                    #print"xxx $i ${1}\[$i\]\n";
                }
            }elsif(/\w+\[\d+/){
                push(@output,$_);
                #print "xxx $_\n";
            }elsif(/(\d+)'b0/){
                for($i=$1;$i>0;$i--){
                    push(@output,"1'b0");
                }
            }elsif(/(\w+)/){
                my $a = $1;
                my $width = &get_wire_width($_);
                if($width ==1){push(@output,"${a}");}
                else{for($i=$width-1;$i>=0;$i--){
                    push(@output,"${a}\[$i]");
                    #print"xxx ${a}\[$i]\n";
                    }
                }
            }
        }
        return(@output);
    }

    sub get_wire_width(){
        my $tmp = shift;
        my $grep = `grep -r $tmp $chip_core`;
        #print"$grep";
        $grep =~ s/\n//g;
        if($grep =~ /wire.*\[(.*)\]/){
            #print"$1\n";
            my $range = $1;
            $range =~ s/\s//g;
            if($range =~ /(\d+):(\d+)/){
                my $width_tmp = $1- $2+1;
                return($width_tmp);
            }
        }elsif($grep =~ /wire.*$tmp/){
            return(1);
        }else{
            print"Warning! $tmp is not defined in $chip_core\n";
        }
    }
