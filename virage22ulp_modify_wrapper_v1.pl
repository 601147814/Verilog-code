#! /usr/bin/perl
    use strict;

#***************************************************************************
# Copyright (c) 2022, liang.zheng
# All rights reserved.
#
# Description:
#    Script to generate ram wrapper code 
#
# version   : 
#           v1 - test, try to add wrapper need split, based on vierage12ffc_modify_wrapper_v01.pl
# Input     :
#   
# Output    : wrapper.v
#
# Author    : liang.zheng
#
#***************************************************************************/
    printf "hello world!\n" ;

    my $process = "suh7";
    my $chip = $ENV{chip} ;
    my $modify_wrapper_path  = './modify_wrapper' ;
    my $orignal_wrapper_path = './orignal_wrapper' ;
    my $input_list ;
    if($ARGV[0] =~ m/(\w+)/){
      $input_list = $ARGV[0] ;
      }
    else {
      $input_list = './wrapper_need_modify.l' ;
      }
    
    system "rm $modify_wrapper_path/*.v $orignal_wrapper_path/*.v -rf" ;
    
#--------------generate wrapper-mem hash,report split mem------------#
    my   %wrapper_mem_hash ;
    my   $wrapper_need_split_fh ;
    open $wrapper_need_split_fh ,'>', "./wrapper_need_split.l" 
         or die "can not open file!:$!" ;
    my   $input_list_fh ;
    open $input_list_fh ,'<', "$input_list" 
         or die "can not open file!:$!" ;
    while (<$input_list_fh>){
         chomp ;
         my @wrapper_info = split(/\,/,$_);
         my $wrapper_name = $wrapper_info[0] ;
         my @mem_info     = split(/\|/,$wrapper_info[2]);
         my $mem_info_num = @mem_info ;
         if ($mem_info_num == 2 and $wrapper_name =~ /(spsram|dprf_)/){
           $wrapper_mem_hash{$wrapper_name} = $mem_info[1] ;
           }
         elsif($mem_info_num > 2 and $wrapper_name =~ /(spsram|dprf_)/){
           $wrapper_mem_hash{$wrapper_name} = $wrapper_info[2] ;
           }else{
           print $wrapper_need_split_fh "$_\n";
           }
    }
    close $input_list_fh ;
    close $wrapper_need_split_fh ;
    
#--------------main part------------#
    foreach my $wrapper(sort keys %wrapper_mem_hash){
       my $mem = $wrapper_mem_hash{$wrapper};
       my $wrapper_size ;
       my $mem_size     ;
       if ($wrapper =~ /(spsram|dprf_1clk|dprf_2clk)_(\d+x\d+)(_|x)/){$wrapper_size = $2;}
       if ($mem     =~ /(dgl|del|dul|dul|drl|ssl|srl)(\d+x\d+)m/)        {$mem_size     = $2;}
       my $wrapper_path = "./$wrapper.v" ;
       &gen_wrapper($wrapper) ;#update 
       $wrapper_path ;
       $mem =~s/\|/;/g;
       my @mem_tmp = split(";",$mem);
       if(@mem_tmp > 2){
           &modify_split_mem($wrapper_path,$wrapper,$mem);
       }else{
         if ($wrapper_size eq $mem_size){
           &modify_same_size($wrapper_path,$wrapper,$mem) ;
           }
         else {     
           &modify_diff_size($wrapper_path,$wrapper,$mem) ;
           }
       }
       system "cp $wrapper_path $orignal_wrapper_path -rf";
       system "rm $wrapper_path -rf";
    }
#--------------main part end------------#

#--------------sub task------------#
sub gen_wrapper{
  my $wrapper = $_[0] ;
  if ($wrapper =~ /\b(a35_(spsram|dprf_1clk|dprf_2clk))_(\d+)x(\d+)(_|x)/) {
    if ($5 eq 'x') {system "$chip/ram/rtl/a35_rams/a35_both_22ulp_ram_wrapper.pl $1 $3 $4 -bit_mask" ;}
    else           {system "$chip/ram/rtl/a35_rams/a35_both_22ulp_ram_wrapper.pl $1 $3 $4 " ;}
    }
  elsif ($wrapper =~ /\b(a73_(spsram|dprf_1clk|dprf_2clk))_(\d+)x(\d+)(_|x)/) {
    if ($5 eq 'x') {system "$chip/ram/rtl/a73rams/a73_both_12ff_ram_wrapper.pl $1 $3 $4 -bit_mask" ;}
    else           {system "$chip/ram/rtl/a73rams/a73_both_12ff_ram_wrapper.pl $1 $3 $4 " ;}
    }
  elsif ($wrapper =~ /\b(a55_(spsram|dprf_1clk|dprf_2clk))_(\d+)x(\d+)(_|x)/) {
    if ($5 eq 'x') {system "$chip/ram/rtl/a55_rams/a55_both_22ulp_ram_wrapper.pl $1 $3 $4 -bit_mask" ;}
    else           {system "$chip/ram/rtl/a55_rams/a55_both_22ulp_ram_wrapper.pl $1 $3 $4 " ;}
    }
  elsif ($wrapper =~ /\b(a53_(spsram|dprf_1clk|dprf_2clk))_(\d+)x(\d+)(_|x)/) {
    if ($5 eq 'x') {system "$chip/ram/rtl/a53_rams/a53_both_22ulp_ram_wrapper.pl $1 $3 $4 -bit_mask" ;}
    else           {system "$chip/ram/rtl/a53_rams/a53_both_22ulp_ram_wrapper.pl $1 $3 $4 " ;}
    }
  elsif ($wrapper =~ /\b(dos_(spsram|dprf_1clk|dprf_2clk))_(\d+)x(\d+)(_|x)/) {
    if ($5 eq 'x') {system "$chip/ram/rtl/dosrams/dos_both_22ulp_ram_wrapper.pl $1 $3 $4 -bit_mask" ;}
    else           {system "$chip/ram/rtl/dosrams/dos_both_22ulp_ram_wrapper.pl $1 $3 $4 " ;}
    }
  elsif ($wrapper =~ /\b(ux900_(spsram|dprf_1clk|dprf_2clk))_(\d+)x(\d+)(_|x)/) {
    if ($5 eq 'x') {system "$chip/nuclei_eval/ux900_2cores_v0p5/design/try_1122/ram/rtl/ux900_both_22ulp_ram_wrapper.pl $1 $3 $4 -bit_mask" ;}
    else           {system "$chip/nuclei_eval/ux900_2cores_v0p5/design/try_1122/ram/rtl/ux900_both_22ulp_ram_wrapper.pl $1 $3 $4 " ;}
    }
  elsif ($wrapper =~ /\b(spsram|dprf_1clk|dprf_2clk)_(\d+)x(\d+)(_|x)/) {
    if ($4 eq 'x') {system "$chip/ram/rtl/both_22ulp_ram_wrapper.pl $1 $2 $3 -bit_mask" ;}
    else           {system "$chip/ram/rtl/both_22ulp_ram_wrapper.pl $1 $2 $3 " ;}
    }
  elsif ($wrapper =~ /\b(adla_(spsram|dprf_1clk|dprf_2clk))_(\d+)x(\d+)(_|x)/) {
    if ($5 eq 'x') {system "$chip/ram_22nm/scripts_for_generate_wrapper/adla_both_12ff_ram_wrapper.pl $1 $3 $4 -bit_mask" ;}
    else           {system "$chip/ram_22nm/scripts_for_generate_wrapper/adla_both_12ff_ram_wrapper.pl $1 $3 $4 " ;}
    }
  elsif ($wrapper =~ /\b(isp_(spsram|dprf_1clk|dprf_2clk))_(\d+)x(\d+)(_|x)/) {
    if ($5 eq 'x') {system "$chip/ram/rtl/isp_rams/isp_both_12ff_ram_wrapper.pl $1 $3 $4 -bit_mask" ;}
    else           {system "$chip/ram/rtl/isp_rams/isp_both_12ff_ram_wrapper.pl $1 $3 $4 " ;}
    }
  else {
    print "ERROR!$wrapper not match\n";
    }
  }

sub modify_same_size{
   my $wrapper_path = $_[0] ;
   my $wrapper      = $_[1] ;
   my $mem          = $_[2] ;

   my $mem_type     = 9999;
   my $mem_cm       = 9999;
   my $mem_bank     = 9999;
   my $mem_cent     = 9999;
   
   if ($mem     =~ /(dgl|del|dul|dul|drl|ssl|srl)(\d+x\d+)m(\d+)b(\d+)w\dc(\d)/)        {
     $mem_type = $1 ;
     $mem_cm   = $3;
     $mem_bank = $4;
     $mem_cent = $5;
     print "test $mem $mem_type $mem_cm $mem_bank $mem_cent\n";
     }
   open my $wrapper_old_fh ,'<', "$wrapper_path" 
        or die "can not open file!:$wrapper_path" ;
   open my $wrapper_new_fh ,'>', "$modify_wrapper_path/$wrapper.v" 
        or die "can not open file!:$!" ;
   while (<$wrapper_old_fh>){
        chomp ;
        s/sadul${process}(l|s|h)2p(\d+x\d+)m2b1w1c0p(\d)d0l0s10/sadul${process}${1}2p$2m${mem_cm}b${mem_bank}w1c${mem_cent}p$3d0l0s10/;
        s/sadrl${process}(l|s|h)2p(\d+x\d+)m2b1w1c0p(\d)d0l0s10/sadrl${process}${1}2p$2m${mem_cm}b${mem_bank}w1c${mem_cent}p$3d0l0s10/;
        if ($mem_type eq 'dgl') {
          s/sadgl${process}(l|s|h)1p(\d+x\d+)m2b1w1c0p(\d)d0t0s10/sadgl${process}${1}1p$2m${mem_cm}b${mem_bank}w1c${mem_cent}p$3d0t0s10/;
          }
        elsif ($mem_type eq 'del'){
          s/sadgl${process}(l|s|h)1p(\d+x\d+)m1b1w1c0p(\d)d0t0s2z1rw00/sadel${process}${1}1p$2m${mem_cm}b${mem_bank}w1c${mem_cent}p$3d0t0s2sdz1rw01/;
        }
        elsif ($mem_type eq 'srl') {
          s/sadgl${process}s1p(\d+x\d+)m2b1w1c0p(\d)d0t0s10/sasrl${process}l1p$1m${mem_cm}b${mem_bank}w1c${mem_cent}p$2d0l0s10/;
          s/sadgl${process}h1p(\d+x\d+)m2b1w1c0p(\d)d0t0s10/sasrl${process}s1p$1m${mem_cm}b${mem_bank}w1c${mem_cent}p$2d0l0s10/;
          }

#        elsif ($mem_type eq 'dul') {
#          s/sadul${process}s1p(\d+x\d+)m2b1w1c0p(\d)d0t0s10/sadul${process}s1p$1m${mem_cm}b${mem_bank}w1c${mem_cent}p$2d0t0s10/;
#          s/sadul${process}h1p(\d+x\d+)m2b1w1c0p(\d)d0t0s10/sadul${process}h1p$1m${mem_cm}b${mem_bank}w1c${mem_cent}p$2d0t0s10/;
#          }
        elsif ($mem_type eq 'ssl'){
          s/sadgl${process}s1p(\d+x\d+)m2b1w1c0p(\d)d0t0s10/sassl${process}l1p$1m${mem_cm}b${mem_bank}w1c${mem_cent}p$2d0t0s10/;
          s/sadgl${process}h1p(\d+x\d+)m2b1w1c0p(\d)d0t0s10/sassl${process}s1p$1m${mem_cm}b${mem_bank}w1c${mem_cent}p$2d0t0s10/;
        }

#        if(/TEST_RNM/ and (($mem_type eq 'del') or ($mem_type eq 'ssl'))){
        if(/TEST_RNM/ and  ($mem_type eq 'del') ){
            print $wrapper_new_fh "               .WA         ( 3'b101    ),\n";
            print $wrapper_new_fh "               .WPULSE     ( 3'b000    ),\n";
        }

        print $wrapper_new_fh "$_\n";
   }

   close $wrapper_old_fh;
   close $wrapper_new_fh;
}


sub modify_diff_size{
   my $wrapper_path = $_[0] ;
   my $wrapper      = $_[1] ;
   my $mem          = $_[2] ;

   my $mem_type     = 9999;
   my $mem_depth    = 9999;
   my $mem_width    = 9999;
   my $mem_cm       = 9999;
   my $mem_bank     = 9999;
   my $mem_cent     = 9999;
   if ($mem     =~ /(dgl|del|dul|dul|drl|ssl|srl)(\d+)x(\d+)m(\d+)b(\d+)w\dc(\d)/)        {
     $mem_type  = $1 ;
     $mem_depth = $2 ;
     $mem_width = $3 ;
     $mem_cm    = $4;
     $mem_bank  = $5;
     $mem_cent  = $6;
     }

   my $wrapper_type     = 9999;  
   my $wrapper_depth    = 9999;
   my $wrapper_width    = 9999;
   if ($wrapper =~ /(spsram|dprf_1clk|dprf_2clk)_(\d+)x(\d+)(_|x)/) {
     $wrapper_type  = $1;
     $wrapper_depth = $2;
     $wrapper_width = $3;
    }
   
   my $mem_width_flag = 0 ;
   my $add_bit        = 0 ;
   my $add_bit_sub1   = 0 ;
   if($mem_width > $wrapper_width){
     $mem_width_flag = 1;
     $add_bit        = $mem_width - $wrapper_width ;
     $add_bit_sub1   = $add_bit - 1 ;
     }

   my $virage_flag = 0 ;
   open my $wrapper_old_fh ,'<', "$wrapper_path" 
        or die "can not open $wrapper_path!:$!" ;
   open my $wrapper_new_fh ,'>', "$modify_wrapper_path/$wrapper.v" 
        or die "can not open file!:$!" ;
   while (<$wrapper_old_fh>){
        chomp;
        if(/\`elsif\s+USE_VIRAGE_MEM/   ){ $virage_flag = 1;}
        elsif(/\`endif/ and $virage_flag){ $virage_flag = 0;}
        
        if (/wire\s+\[\d+\:\d+\]\s+Q_pre\;/ and $virage_flag and $mem_width_flag){
          if ($add_bit_sub1 != 0) {
              print $wrapper_new_fh "wire  [$add_bit_sub1\:0]  Q_pre_nc\;\n";
            }
          else {
              print $wrapper_new_fh "wire       Q_pre_nc\;\n";
            }
         }

        if ($wrapper_type eq 'dprf_1clk' and $virage_flag and $mem_width_flag){
           s/(\.DA\s*\(\s*)D_d(\s*\)\,)/$1\{${add_bit}\'h0\,D_d\}$2/;
           s/(\.WEMA\s*\(\s*\{)\d+(\{1\'b1\}\}\s*\)\,)/$1${mem_width}$2/;
           s/(\.WEMA\s*\(\s*\~)BITWENB_d(\s*\)\,)/$1\{${add_bit}\'h0\,BITWENB_d\}$2/;
           s/(\.QB\s*\(\s*)Q_pre(\s*\)\,)/$1\{Q_pre_nc\,Q_pre\}$2/;
        }
        if ($wrapper_type eq 'dprf_2clk' and $virage_flag and $mem_width_flag){
           s/(\.DA\s*\(\s*)D_d(\s*\)\,)/$1\{${add_bit}\'h0\,D_d\}$2/;
           s/(\.WEMA\s*\(\s*\~)BITWENB_d(\s*\)\,)/$1\{${add_bit}\'h0\,BITWENB_d\}$2/;
           s/(\.QB\s*\(\s*)Q_pre(\s*\)\,)/$1\{Q_pre_nc\,Q_pre\}$2/;
        }
        if ($wrapper_type eq 'spsram' and $virage_flag and $mem_width_flag){
           s/(\.D\s*\(\s*)D_d(\s*\)\,)/$1\{${add_bit}\'h0\,D_d\}$2/;
           s/(\.WEM\s*\(\s*\{)\d+(\{1\'b1\}\}\s*\)\,)/$1${mem_width}$2/;
           s/(\.WEM\s*\(\s*\~)BITWEN_d(\s*\)\,)/$1\{${add_bit}\'h0\,BITWEN_d\}$2/;
           s/(\.Q\s*\(\s*)Q_pre(\s*\)\,)/$1\{Q_pre_nc\,Q_pre\}$2/;
        }

        s/sadul${process}(l|s|h)2p(\d+x\d+)m2b1w1c0p(\d)d0l0s10/sadul${process}${1}2p${mem_depth}x${mem_width}m${mem_cm}b${mem_bank}w1c${mem_cent}p$3d0l0s10/;
        s/sadrl${process}(l|s|h)2p(\d+x\d+)m2b1w1c0p(\d)d0l0s10/sadrl${process}${1}2p${mem_depth}x${mem_width}m${mem_cm}b${mem_bank}w1c${mem_cent}p$3d0l0s10/;
        if ($mem_type eq 'dgl') {
          s/sadgl${process}(l|s|h)1p(\d+x\d+)m2b1w1c0p(\d)d0t0s10/sadgl${process}${1}1p${mem_depth}x${mem_width}m${mem_cm}b${mem_bank}w1c${mem_cent}p$3d0t0s10/;
          }
        elsif ($mem_type eq 'del'){
          s/sadgl${process}(l|s|h)1p(\d+x\d+)m1b1w1c0p(\d)d0t0s2z1rw00/sadel${process}${1}1p${mem_depth}x${mem_width}m${mem_cm}b${mem_bank}w1c${mem_cent}p$3d0t0s2sdz1rw01/;
          }
        elsif ($mem_type eq 'srl'){
          s/sadgl${process}s1p(\d+x\d+)m2b1w1c0p(\d)d0t0s10/sasrl${process}l1p${mem_depth}x${mem_width}m${mem_cm}b${mem_bank}w1c${mem_cent}p$2d0l0s10/;
          s/sadgl${process}h1p(\d+x\d+)m2b1w1c0p(\d)d0t0s10/sasrl${process}s1p${mem_depth}x${mem_width}m${mem_cm}b${mem_bank}w1c${mem_cent}p$2d0l0s10/;
          }
#        elsif ($mem_type eq 'dul'){
#          s/sadul${process}s1p(\d+x\d+)m2b1w1c0p(\d)d0t0s10/sadul${process}s1p${mem_depth}x${mem_width}m${mem_cm}b${mem_bank}w1c${mem_cent}p$2d0t0s10/;
#          s/sadul${process}h1p(\d+x\d+)m2b1w1c0p(\d)d0t0s10/sadul${process}h1p${mem_depth}x${mem_width}m${mem_cm}b${mem_bank}w1c${mem_cent}p$2d0t0s10/;
#          }
        elsif ($mem_type eq 'ssl'){
          s/sadgl${process}s1p(\d+x\d+)m2b1w1c0p(\d)d0t0s10/sassl${process}l1p${mem_depth}x${mem_width}m${mem_cm}b${mem_bank}w1c${mem_cent}p$2d0t0s10/;
          s/sadgl${process}h1p(\d+x\d+)m2b1w1c0p(\d)d0t0s10/sassl${process}l1p${mem_depth}x${mem_width}m${mem_cm}b${mem_bank}w1c${mem_cent}p$2d0t0s10/;
          }

          if(/TEST_RNM/ and (($mem_type eq 'del') or ($mem_type eq 'ssl'))){
            print $wrapper_new_fh "               .WA         ( 3'b101    ),\n";
            print $wrapper_new_fh "               .WPULSE     ( 3'b000    ),\n";
          }

        print $wrapper_new_fh "$_\n";
   }

   close $wrapper_old_fh;
   close $wrapper_new_fh;
}

    sub modify_split_mem{
        my $wrapper_path = $_[0] ;
        my $wrapper      = $_[1] ;
        my $mem          = $_[2] ;

        #print"xxx $wrapper_path $wrapper $mem\n";

        my $wrapper_type     = 9999;  
        my $wrapper_depth    = 9999;
        my $wrapper_depth_width;
        my $wrapper_width    = 9999;
        my $wrapper_mask ;
        if ($wrapper =~ /(spsram|dprf_1clk|dprf_2clk)_(\d+)x(\d+)(_|xMASK)/) {
            $wrapper_type  = $1;
            $wrapper_depth = $2;
            $wrapper_width = $3;
            if($4=~/MASK/){$wrapper_mask = 1}
            else{$wrapper_mask = 0}
            $wrapper_depth_width = int(log($wrapper_depth)/log(2) + 0.999999);
        }

        $mem =~ s/\|/;/g;
        my @mem_split = split(";",$mem);
        my $mem_num;
        my $nw_split = 0;my $nw_need_split = 0;
        my $nb_split = 0;my $nb_need_split = 0; 
        
        my $i=0;
        foreach(@mem_split){
            if(/sa(dgl|ssl|dul|drl|srl|cul)${process}(s|l|u|h)(\d)p(\d+)x(\d+)m/){
                
                $nw_split += $4;
                $nb_split += $5;
                $i++
            }
        }
        if($nw_split >= ($wrapper_depth*$i)){$nb_need_split = 1}
        if($nb_split >= ($wrapper_width*$i)){$nw_need_split = 1}


        my $reg_width;
        if($nw_need_split){
            $mem_num = @mem_split; 
            $reg_width = int(log($mem_num)/log(2) + 0.999999);
        }

        
        my $add_bit        = 0 ;
        my $add_bit_sub1   = 0 ;
        my $mem_width_flag = 0 ;
        if($nb_split > $wrapper_width & $nb_need_split == 1){
            $mem_width_flag = 1;
            $add_bit        = $nb_split - $wrapper_width ;
            $add_bit_sub1   = $add_bit - 1;
        }
        
        my $virage_flag = 0 ;
        open my $wrapper_old_fh ,'<', "$wrapper_path" or die "can not open $wrapper_path!:$!" ;
        open my $wrapper_new_fh ,'>', "$modify_wrapper_path/$wrapper.v" or die "can not open file!:$!" ;
        while (<$wrapper_old_fh>){
            chomp ;
            if(/\`elsif\s+USE_VIRAGE_MEM/   ){ $virage_flag = 1;print $wrapper_new_fh "$_\n"}
            elsif(/\`endif/ and $virage_flag){ $virage_flag = 0;}

            if(/\`elsif\s+USE_VIRAGE_MEM/){
                print $wrapper_new_fh "// -------------------------------------------------------------------------------------\n";
                print $wrapper_new_fh "// Example wiring for an actual memory model.   Power gated memories are much bigger than\n";
                print $wrapper_new_fh "// non power gated memories so there is a parameter allowing a module to instiate either.\n";
                print $wrapper_new_fh "//\n";

                #print $wrapper_new_fh "xxx $mem_width_flag $nw_need_split $nb_need_split $mem_num yyy $reg_width\n";
                
                if($wrapper_type =~ /spsram/ & $wrapper_mask){
                    print $wrapper_new_fh "wire WEN_d = &BITWEN_d;\n";
                }
                
                if ( $nb_need_split){
                    print $wrapper_new_fh "wire    [$wrapper_width-1:0]\tQ_pre;\n";
                    if ($add_bit > 1) { print $wrapper_new_fh "wire    [$add_bit-1\:0]\tQ_pre_nc\;\n";} 
                    elsif($add_bit == 1)              { print $wrapper_new_fh "wire       Q_pre_nc\;\n";}
                }elsif(  $nw_need_split){
                    print $wrapper_new_fh "wire    [$wrapper_width-1:0]    Q_pre;\n";
                    
                    $i=0;
                    foreach(@mem_split){
                        if(/sa(crl|del|ssl|dul|drl|srl|cul)${process}(s|l|u|h)(\d)p(\d+)x(\d+)m/){
                            print $wrapper_new_fh "wire    [$wrapper_width-1:0]    Q_pre$i;\n";
                            $i++;
                        }
                    }

                    if($reg_width == 1){print $wrapper_new_fh "reg\t\trd_sel\n";}
                    else{               print $wrapper_new_fh "reg     [$reg_width-1:0]\trd_sel;\n"}

                   
                    $i=0;
                    my $addr_tmp_sof = 0;
                    my $addr_tmp_eof = 0;
                    foreach(@mem_split){
                        if(/sa(dgl|del|ssl|dul|drl|srl|cul)${process}(s|l|u|h)(\d)p(\d+)x(\d+)m/){
                            my $nw_tmp = $4;
                            $addr_tmp_eof+=$nw_tmp;
                            if($wrapper_type =~ /dprf_(1|2)clk/){print $wrapper_new_fh "wire    CENW_d$i = (AW_d >= $addr_tmp_sof\t& AW_d < $addr_tmp_eof\t) & ~CENW_d;\n";}
                            elsif($wrapper_type =~ /spsram/)    {print $wrapper_new_fh "wire    WEN_d$i = (A_d >= $addr_tmp_sof\t& A_d < $addr_tmp_eof\t) & ~WEN_d;\n";}
                            $addr_tmp_sof+=$nw_tmp;
                            $i++;
                        }
                    }

                    $i=0;
                    my $addr_tmp_sof = 0;
                    my $addr_tmp_eof = 0;
                    foreach(@mem_split){
                        if(/sa(dgl|del|ssl|dul|drl|srl|cul)${process}(s|l|u|h)(\d)p(\d+)x(\d+)m/){
                            my $nw_tmp = $4;
                            $addr_tmp_eof+=$nw_tmp;
                            if($wrapper_type =~ /dprf_(1|2)clk/){print $wrapper_new_fh "wire    CENR_d$i = (AR_d >= $addr_tmp_sof\t& AR_d < $addr_tmp_eof\t) & ~CENR_d;\n";}
                            elsif($wrapper_type =~ /spsram/)    {print $wrapper_new_fh "wire    CEN_d$i = (A_d >= $addr_tmp_sof\t& A_d < $addr_tmp_eof\t) & ~CEN_d;\n";}
                            $addr_tmp_sof+=$nw_tmp;
                            $i++;
                        }
                    }
                }

                print $wrapper_new_fh "//\n";
                print $wrapper_new_fh "generate\n";

                my $n;
                for($n=0;$n<4;$n++){
                    if($n == 0)   {
                        print $wrapper_new_fh "\tif( PGMEM == 1\'b1 ) begin : pgmem             // Power gated memory\n";
                        print $wrapper_new_fh "\t\tif( HSEN == 1\'b1 ) begin : hs             \n";
                    }elsif($n == 1){
                        print $wrapper_new_fh "\t\tend\n";
                        print $wrapper_new_fh "\t\telse begin :not_hs\n";
                    }elsif($n == 2){
                        print $wrapper_new_fh "\t\tend \n";
                        print $wrapper_new_fh "\tend else begin: not_pgmem       // NOT a power gated memory\n";
                        print $wrapper_new_fh "\t\tif( HSEN == 1\'b1 ) begin : hs         \n";
                    }elsif($n == 3){
                        print $wrapper_new_fh "\t\tend else begin : not_hs         \n";
                    }
                    
                    
                    my $mem_type;
                    $i=0;
                    my $nb_sof=0; my $nb_eof = 0;
                    my $nw_width; my $nb_width ;
                    foreach(@mem_split){
                        if(/sa(crl|del|ssl|dul|drl|srl|cul)${process}(s|l|u|h)(\d)p(\d+)x(\d+)m/){
                            $mem_type = $1;
                            $nw_width = int(log($4)/log(2)+0.99999);
                            $nb_width = $5;
                            $nb_eof += $nb_width;
                        }else{next}
                            
                        if($nb_width>$wrapper_width & $nw_need_split){
                            my $nb_add = $nb_width - $wrapper_width;
                            if($nb_add == 1){print $wrapper_new_fh "\t\twire Q_pre${i}_nc;\n";}
                            else{print $wrapper_new_fh "\t\twire[$nb_add-1:0]Q_pre${i}_nc;\n";}
                        }

                        if(/(sa\w+${process})\w(\dp\d+x\d+m.*p)\d(\w+)/){
                            if($n == 0)   {print $wrapper_new_fh "\t\t${1}l${2}1$3 u$i (\n";}
                            elsif($n == 1){print $wrapper_new_fh "\t\t${1}s${2}1$3 u$i (\n";}
                            elsif($n == 2){print $wrapper_new_fh "\t\t${1}l${2}0$3 u$i (\n";}
                            elsif($n == 3){print $wrapper_new_fh "\t\t${1}s${2}0$3 u$i (\n";}
                        }                                                  
                        
                        if($nb_need_split){
                            if($nb_eof<=$wrapper_width){
                                if($wrapper_type =~ /dprf_(1|2)clk/){
                                    print $wrapper_new_fh     "\t\t\t// Write port\n";
                                    if($wrapper_depth_width == $nw_width){
                                        print $wrapper_new_fh     "\t\t\t.ADRA      ( AW_d[$nw_width-1:0]\t),\n";
                                    }elsif($wrapper_depth_width < $nw_width){
                                        my $nw_add = $nw_width - $wrapper_depth_width;
                                        print $wrapper_new_fh     "\t\t\t.ADRA      ( {$nw_add\'b0,AW_d[$wrapper_depth_width-1:0]}\t),\n";
                                    }
                                    print $wrapper_new_fh     "\t\t\t.DA        ( D_d[$nb_sof+:$nb_width]\t),\n";
                                    print $wrapper_new_fh     "\t\t\t.MEA       ( ~CENW_d\t\t),\n";
                                    print $wrapper_new_fh     "\t\t\t.WEA       ( ~CENW_d\t\t),\n";
                                    if($wrapper_mask){
                                        print $wrapper_new_fh "\t\t\t.WEMA      ( ~BITWENB_d\[$nb_sof+:$nb_width]\t),\n";
                                    }else{             
                                        print $wrapper_new_fh "\t\t\t.WEMA      ( \{$nb_width\{1\'b1}}\t),\n";
                                    }
                                    if($wrapper_type =~ /dprf_1clk/){
                                        print $wrapper_new_fh "\t\t\t.CLK       ( CLK_g\t\t\t),\n";
                                    }elsif($wrapper_type =~ /dprf_2clk/){
                                        print $wrapper_new_fh "\t\t\t.CLKA      ( CLKW_g\t\t\t),\n";
                                    }
                                    print $wrapper_new_fh     "\t\t\t// Read port\n";
                                    if($wrapper_depth_width == $nw_width){
                                        print $wrapper_new_fh     "\t\t\t.ADRB      ( AR_d[$nw_width-1:0]\t),\n";
                                    }elsif($wrapper_depth_width < $nw_width){
                                        my $nw_add = $nw_width - $wrapper_depth_width;
                                        print $wrapper_new_fh     "\t\t\t.ADRB      ( {$nw_add\'b0,AR_d[$wrapper_depth_width-1:0]}\t),\n";
                                    }
                                    print $wrapper_new_fh     "\t\t\t.MEB       ( ~CENR_d\t\t),\n";
                                    print $wrapper_new_fh     "\t\t\t.QB        ( Q_pre[$nb_sof+:$nb_width]\t),\n";
                                    if($wrapper_type =~ /dprf_2clk/){
                                        print $wrapper_new_fh "\t\t\t.CLKB      ( CLKR_g\t\t\t),\n";
                                    }
                                }elsif($wrapper_type =~ /spsram/){
                                    print $wrapper_new_fh     "\t\t\t.CLK       ( CLK_g\t\t\t),\n";
                                    print $wrapper_new_fh     "\t\t\t.ME        ( ~CEN_d\t\t\t),\n";
                                    print $wrapper_new_fh     "\t\t\t.WE        ( ~WEN_d\t\t\t),\n";
                                    if($wrapper_mask){
                                        print $wrapper_new_fh "\t\t\t.WEM       ( ~BITWEN_d\[$nb_sof+:$nb_width]\t),\n";
                                    }else{             
                                        print $wrapper_new_fh "\t\t\t.WEM       ( \{$nb_width\{1\'b1}}\t),\n";
                                    }
                                    if($wrapper_depth_width == $nw_width){
                                        print $wrapper_new_fh     "\t\t\t.ADR       ( A_d[$nw_width-1:0]\t),\n";
                                    }elsif($wrapper_depth_width < $nw_width){
                                        my $nw_add = $nw_width - $wrapper_depth_width;
                                        print $wrapper_new_fh     "\t\t\t.ADR       ( {$nw_add\'b0,A_d[$wrapper_depth_width-1:0]}\t),\n";
                                    }
                                    print $wrapper_new_fh     "\t\t\t.D         ( D_d[$nb_sof+:$nb_width]\t),\n";
                                    print $wrapper_new_fh     "\t\t\t.Q         ( Q_pre[$nb_sof+:$nb_width]\t),\n";
                                }
                            }else{
                                my $nb_left = $wrapper_width - $nb_sof;
                                if($wrapper_type =~ /dprf_(1|2)clk/){
                                    print $wrapper_new_fh     "\t\t\t// Write port\n";
                                    if($wrapper_depth_width == $nw_width){
                                        print $wrapper_new_fh     "\t\t\t.ADRA      ( AW_d[$nw_width-1:0]\t),\n";
                                    }elsif($wrapper_depth_width < $nw_width){
                                        my $nw_add = $nw_width - $wrapper_depth_width;
                                        print $wrapper_new_fh     "\t\t\t.ADRA      ( {$nw_add\'b0,AW_d[$wrapper_depth_width-1:0]}\t),\n";                                    
                                    }
                                    print $wrapper_new_fh     "\t\t\t.DA        ( {$add_bit\'d0,D_d[$nb_sof+:$nb_left]}\t),\n";
                                    print $wrapper_new_fh     "\t\t\t.MEA       ( ~CENW_d\t\t),\n";
                                    print $wrapper_new_fh     "\t\t\t.WEA       ( ~CENW_d\t\t),\n";
                                    if($wrapper_mask){
                                        print $wrapper_new_fh "\t\t\t.WEMA      ( ~\{$add_bit\'d0,BITWENB_d[$nb_sof+:$nb_left]}\t),\n";
                                    }else{
                                        print $wrapper_new_fh "\t\t\t.WEMA      ( \{$nb_width\{1\'b1}}\t),\n";
                                    }
                                    if($wrapper_type =~ /(dprf_1clk)/){
                                        print $wrapper_new_fh "\t\t\t.CLK       ( CLK_g\t\t\t),\n";
                                    }elsif($wrapper_type =~ /dprf_2clk/){
                                        print $wrapper_new_fh "\t\t\t.CLKA      ( CLKW_g\t\t\t),\n";
                                    }
                                    print $wrapper_new_fh     "\t\t\t// Read port\n";
                                    if($wrapper_depth_width == $nw_width){
                                        print $wrapper_new_fh     "\t\t\t.ADRB      ( AR_d[$nw_width-1:0]\t),\n";
                                    }elsif($wrapper_depth_width < $nw_width){
                                        my $nw_add = $nw_width - $wrapper_depth_width;
                                        print $wrapper_new_fh     "\t\t\t.ADRB      ( {$nw_add\'b0,AR_d[$wrapper_depth_width-1:0]}\t),\n";
                                    }
                                    print $wrapper_new_fh     "\t\t\t.MEB       ( ~CENR_d\t\t),\n";
                                    print $wrapper_new_fh     "\t\t\t.QB        ( {Q_pre_nc,Q_pre[$nb_sof+:$nb_left]}\t),\n";
                                    if($wrapper_type =~ /dprf_2clk/){
                                        print $wrapper_new_fh "\t\t\t.CLKB      ( CLKR_g\t\t\t),\n";
                                    }
                                }elsif($wrapper_type =~ /spsram/){
                                    print $wrapper_new_fh     "\t\t\t.CLK       ( CLK_g\t\t\t),\n";
                                    print $wrapper_new_fh     "\t\t\t.ME        ( ~CEN_d\t\t\t),\n";
                                    print $wrapper_new_fh     "\t\t\t.WE        ( ~WEN_d\t\t\t),\n";
                                    if($wrapper_mask){ 
                                        print $wrapper_new_fh "\t\t\t.WEM       ( ~\{$add_bit\'d0,BITWEN_d\[$nb_sof+:$nb_left]}\t),\n";
                                    }else{
                                        print $wrapper_new_fh "\t\t\t.WEM       ( \{$nb_width\{1\'b1}}\t),\n";
                                    }
                                    if($wrapper_depth_width == $nw_width){
                                        print $wrapper_new_fh     "\t\t\t.ADR       ( A_D[$nw_width-1:0]\t),\n"
                                    }elsif($wrapper_depth_width < $nw_width){
                                        my $nw_add = $nw_width - $wrapper_depth_width;
                                        print $wrapper_new_fh     "\t\t\t.ADR       ( {$nw_add\'b0,A_D[$wrapper_depth_width-1:0]}\t),\n"
                                    }
                                    print $wrapper_new_fh     "\t\t\t.D         ( {$add_bit\'d0,D_d[$nb_sof+:$nb_left]}\t),\n";
                                    print $wrapper_new_fh     "\t\t\t.Q         ( {Q_pre_nc,Q_pre[$nb_sof+:$nb_left]}\t),\n";

                                }
                            }
                        }elsif($nw_need_split){
                            if($wrapper_type =~ /dprf_(1|2)clk/){ 
                                print $wrapper_new_fh         "\t\t\t// Write port\n";
                                print $wrapper_new_fh         "\t\t\t.ADRA      ( AW_d[$nw_width-1:0]\t),\n";
                            
                                if($nb_width==$wrapper_width){
                                    print $wrapper_new_fh     "\t\t\t.DA        ( D_d\t\t\t),\n";
                                    if($wrapper_mask){
                                        print $wrapper_new_fh     "\t\t\t.WEMA      ( ~BITWENB_d\t\t),\n";
                                    }else{
                                        print $wrapper_new_fh     "\t\t\t.WEMA      ( {$nb_width\{1\'b1}}\t),\n";
                                    }
                                }elsif($nb_width>$wrapper_width){
                                    my $nw_add_w = $nb_width - $wrapper_width;
                                    print $wrapper_new_fh     "\t\t\t.DA        ( {$nw_add_w\'d0,D_d[0+:$wrapper_width]}\t),\n";
                                    if($wrapper_mask){
                                        print $wrapper_new_fh "\t\t\t.WEMA      ( ~{$nw_add_w\'d0,BITWENB_d[0+:$wrapper_width]}\t\t),\n";
                                    }else{
                                        print $wrapper_new_fh "\t\t\t.WEMA      ( {$nb_width\{1\'b1}}\t),\n";
                                    }
                                }else{
                                    die"nb_width:$nb_width: > wrapper_width:$wrapper_width!\n";
                                }
                                print $wrapper_new_fh         "\t\t\t.MEA       ( CENW_d$i\t\t),\n";
                                print $wrapper_new_fh         "\t\t\t.WEA       ( CENW_d$i\t\t),\n";
                                if($wrapper_type =~ /dprf_1clk/){
                                    print $wrapper_new_fh     "\t\t\t.CLK       ( CLK_g\t\t\t),\n";
                                }elsif($wrapper_type =~ /dprf_2clk/){
                                    print $wrapper_new_fh     "\t\t\t.CLKA      ( CLKW_g\t\t\t),\n";
                                }
                                print $wrapper_new_fh         "\t\t\t// Read port\n";
                                print $wrapper_new_fh         "\t\t\t.ADRB      ( AR_d[$nw_width-1:0]\t),\n";
                                print $wrapper_new_fh         "\t\t\t.MEB       ( CENR_d$i\t\t),\n";
                                if($nb_width==$wrapper_width){
                                    print $wrapper_new_fh     "\t\t\t.QB        ( Q_pre${i}\t\t\t),\n";
                                }elsif($nb_width>$wrapper_width){
                                    print $wrapper_new_fh     "\t\t\t.QB        ( \{Q_pre${i}_nc,Q_pre$i}\t),\n";
                                }
                                if($wrapper_type =~ /dprf_2clk/){
                                    print $wrapper_new_fh     "\t\t\t.CLKB      ( CLKR_g\t\t\t),\n";
                                }
                            }elsif($wrapper_type =~ /spsram/){
                                print $wrapper_new_fh         "\t\t\t.CLK       ( CLK_g\t\t\t),\n";
                                print $wrapper_new_fh         "\t\t\t.ME        ( CEN_d$i\t\t\t),\n";
                                print $wrapper_new_fh         "\t\t\t.WE        ( WEN_d$i\t\t\t),\n";
                                if($wrapper_mask){
                                    if($nb_width > $wrapper_width){
                                        my $add_bit = $nb_width - $wrapper_width;
                                        print $wrapper_new_fh "\t\t\t.WEM       ( ~\{$add_bit\'d0,BITWEN_d\[0+:$wrapper_width]}\t),\n";
                                    }else{
                                        print $wrapper_new_fh "\t\t\t.WEM       ( ~BITWEN_d\[0+:$wrapper_width]\t),\n";
                                    }
                                }else{             
                                    print $wrapper_new_fh     "\t\t\t.WEM       ( \{$nb_width\{1\'b1}}\t\t),\n";
                                }
                                print $wrapper_new_fh         "\t\t\t.ADR       ( A_d[$nw_width-1:0]\t),\n";
                                if($nb_width > $wrapper_width){
                                    my $add_bit = $nb_width - $wrapper_width;
                                    print $wrapper_new_fh     "\t\t\t.D         ( {$add_bit\'d0,D_d[0+:$wrapper_width]}\t),\n";
                                    print $wrapper_new_fh     "\t\t\t.Q         ( {Q_pre${i}_nc,Q_pre${i}\[0+:$wrapper_width]}\t),\n";
                                }else{
                                    print $wrapper_new_fh     "\t\t\t.D         ( D_d[$nb_width-1:0]\t),\n";
                                    print $wrapper_new_fh     "\t\t\t.Q         ( Q_pre${i}\[$nb_width-1:0]\t),\n";
                                }                        
                            }
                        }

                        print $wrapper_new_fh "\t\t\t// Misc\n";

                        if($wrapper_type =~ /spsram/){
                            print $wrapper_new_fh "\t\t\t.RME       ( 1'b0\t\t\t),\n";
                            print $wrapper_new_fh "\t\t\t.RM        ( 4'b0\t\t\t),\n";
                            print $wrapper_new_fh "\t\t\t.TEST1     ( 1'b0\t\t\t),\n";
                            print $wrapper_new_fh "\t\t\t.LS        ( 1'b0\t\t\t),\n";

                            #if($mem_type =~ /ssl/){
                            #    print $wrapper_new_fh "\t\t\t.BC1       ( 1'b0\t\t\t),\n";
                            #    print $wrapper_new_fh "\t\t\t.BC2       ( 1'b0\t\t\t),\n";
                            #    print $wrapper_new_fh "\t\t\t.TEST_RNM  ( 1'b0\t\t\t),\n";
                            #}
                            
                            if($n<2 ){
                                print $wrapper_new_fh "\t\t\t.LS        ( 1'b0\t\t\t),\n";
                                print $wrapper_new_fh "\t\t\t.DS        ( 1'b0\t\t\t),\n";
                                print $wrapper_new_fh "\t\t\t.SD        ( PD[1]\t\t\t));\n";
                            }else{
                                print $wrapper_new_fh "\t\t\t.LS        ( 1'b0\t\t\t));\n";
                            }
                        }elsif($wrapper_type =~ /dprf_1clk/){
                            print $wrapper_new_fh "\t\t\t.TEST1     ( 1'b0\t\t\t), \n";
                            print $wrapper_new_fh "\t\t\t.RM        ( 4'b0\t\t\t), \n";
                            print $wrapper_new_fh "\t\t\t.RME       ( 1'h0\t\t\t), \n";
                            print $wrapper_new_fh "\t\t\t.TESTRWM   ( 1'b0\t\t\t), \n";
                            #print $wrapper_new_fh "\t\t\t.TEST_RNM  ( 1'b0\t\t\t), \n";
                            #print $wrapper_new_fh "\t\t\t.BC1       ( 1'b0\t\t\t), \n";

                            if($n<2){
                                #print $wrapper_new_fh "\t\t\t.BC2       ( 1'b0\t\t\t), \n";
                                #print $wrapper_new_fh "\t\t\t.ROP       (\t\t\t\t), \n";
                                print $wrapper_new_fh "\t\t\t.LS        ( 1'b0\t\t\t), \n";
                                print $wrapper_new_fh "\t\t\t.DS        ( 1'b0\t\t\t), \n";
                                print $wrapper_new_fh "\t\t\t.SD        ( PD[1]\t\t\t));\n";
                            }else{
                                print $wrapper_new_fh "\t\t\t.LS        ( 1'b0\t\t\t)); \n";
                                #print $wrapper_new_fh "\t\t\t.BC2       ( 1'b0\t\t\t)); \n";
                            }
                        }elsif($wrapper_type =~ /dprf_2clk/){
                            #print $wrapper_new_fh "\t\t\t.ROP       (\t\t\t\t),\n" ;
                            print $wrapper_new_fh "\t\t\t.TEST1A    ( 1'b0\t\t\t),\n" ;
                            print $wrapper_new_fh "\t\t\t.RMA       ( 4'b0\t\t\t),\n" ;
                            print $wrapper_new_fh "\t\t\t.RMEA      ( 1'h0\t\t\t),\n" ;
                            print $wrapper_new_fh "\t\t\t.TEST1B    ( 1'b0\t\t\t),\n" ;
                            print $wrapper_new_fh "\t\t\t.RMB       ( 4'b0\t\t\t),\n" ;
                            print $wrapper_new_fh "\t\t\t.RMEB      ( 1'h0\t\t\t),\n" ;
                            
                            if($n<2){
                                print $wrapper_new_fh "\t\t\t.LS        ( 1'b0\t\t\t),\n" ;
                                print $wrapper_new_fh "\t\t\t.DS        ( 1'b0\t\t\t),\n" ;
                                print $wrapper_new_fh "\t\t\t.SD        ( PD[1]\t\t\t));\n";
                            }else{
                                print $wrapper_new_fh "\t\t\t.LS        ( 1'b0\t\t\t));\n" ;
                            }
                        }
                        
                        $i++;
                        $nb_sof += $nb_width;                                     
                    }
                }
                print $wrapper_new_fh "\t\tend\n ";
                print $wrapper_new_fh "\tend\n ";
                
                if($nw_need_split){
                    if($wrapper_type =~ /dprf_2clk/){print $wrapper_new_fh "\talways@(posedge CLKR_g)begin\n ";}
                    else                            {print $wrapper_new_fh "\talways@(posedge CLK_g)begin\n ";}
                    
                    $i=0;
                    my $addr_tmp_sof = 0;
                    my $addr_tmp_eof = 0;
                    foreach(@mem_split){
                        if(/sa(crl|del|ssl|dul|drl|srl|cul)${process}(s|l|u|h)(\d)p(\d+)x(\d+)m/){
                            my $nw_tmp = $4;
                            $addr_tmp_eof+=$nw_tmp;
                            if($i == 0 ){
                                if($wrapper_type =~ /dprf_(1|2)clk/){print $wrapper_new_fh "\t\tif     (AR_d >= $addr_tmp_sof\t& AR_d < $addr_tmp_eof\t)begin rd_sel <= $reg_width\'d$i; end\n";}
                                elsif($wrapper_type =~ /spsram/)    {print $wrapper_new_fh "\t\tif     (A_d >= $addr_tmp_sof\t& A_d < $addr_tmp_eof\t)begin rd_sel <= $reg_width\'d$i; end\n";}
                            }else{
                                if($wrapper_type =~ /dprf_(1|2)clk/){print $wrapper_new_fh "\t\telse if(AR_d >= $addr_tmp_sof\t& AR_d < $addr_tmp_eof\t)begin rd_sel <= $reg_width\'d$i; end\n";}
                                elsif($wrapper_type =~ /spsram/)    {print $wrapper_new_fh "\t\telse if(A_d >= $addr_tmp_sof\t& A_d < $addr_tmp_eof\t)begin rd_sel <= $reg_width\'d$i; end\n";}
                            }
                            $addr_tmp_sof+=$nw_tmp;
                            $i++;                            
                        }
                    }
                    print $wrapper_new_fh "\t\telse begin rd_sel <= $reg_width\'d0; end\n ";
                    print $wrapper_new_fh "\tend\n ";

                    $i=0;
                    foreach(@mem_split){
                        if(/sa(crl|del|ssl|dul|drl|srl|cul)${process}(s|l|u|h)(\d)p(\d+)x(\d+)m/){
                            if($i == 0){print $wrapper_new_fh "\tassign Q_pre = (rd_sel == $reg_width\'d$i) ? Q_pre$i:\n";}
                            else{       print $wrapper_new_fh "\t               (rd_sel == $reg_width\'d$i) ? Q_pre$i:\n";}
                            $i++;
                        }
                    }

                    print $wrapper_new_fh "\t                               $wrapper_width\'d0;\n";                    
                }                
                print $wrapper_new_fh "endgenerate\n";
            }

            if($virage_flag == 0){print $wrapper_new_fh "$_\n"}
        }
        close $wrapper_old_fh;
        close $wrapper_new_fh;
    }
    
