#! /usr/bin/perl
    use strict;

#***************************************************************************
# Copyright (c) 2023, liang.zheng
# All rights reserved.
#
# Description:
#    Script to print model name in wrapper list 
#
# version   : 
#           v1 - test
#           v2 - try 
#           v3 - 
#           v4 - list all possible nw/nb combination to check best model
#           v5 - add tcc match
#	    v6 - add sub function that ram wrapper need to be split
# Input     :
#   
# Output    : mem_list.l wrapper_need_modify.l module_change_report.csv
#
# Author    : liang.zheng
#
#***************************************************************************/

#	22nm
#   type,name,ram/rom,size,speed
#   drl ts22nuh72p11sadrl128sa07    dprf_2clk
#   dul ts22nuh72p11sadul128sa06    dprf_1clk RF
#   dul ts22nuh72p11sadul01msa02p1  dprf_1clk SRAM
#   dul ts22nuh71p11sadul02msa07p2  spsram    SRAM NHS
#   dvl ts22nuh71p10asdvl01msa03p2  rom
#   srl ts22nuh71p11sasrl128sa05p1  spsram    RF   HS
#   ssl ts22nuh71p11sassl01msa02p3  spsram    SRAM HS
#   dgl ts22nuh71p11sadgl128sa05p2  spsram    RF   NHS
#   dsl ts22nuh72p22sadsl01msa07p3  dspsram

    my $chip            = $ENV{chip} ;
    my $show_log_path   = "$chip/top/test/test003/log/verilog.log" ;
    my $csv_lib_path    = '/proj/allproj/Memories_compiler/virage_22ulp_20220121/csv_lib' ;
    my $ram_lib_path    = '/proj/allproj/Memories_compiler/virage_22ulp_20220121/ram_lib' ;
    my $ram_model_file  = "$chip/ram/rtl/ram_model.f";
    my $tcc_corner      = 'ssgwct0p9vn40c' ;
    my $power_corner    = 'tt1p0v85c' ;
    my $process         = 'suh7';

    print "project: $chip\n";
    print "csv lib: $csv_lib_path\n";
    print "ram lib: $ram_lib_path\n";
    print "tcc cornor: $tcc_corner\n";
    print "power cornor: $power_corner\n";
    print "output file: mem_list.l wrapper_need_modify.l module_change_report\n";

    my $work_mode;
    if   ($ARGV[0] eq 'normal'){       $work_mode = 'normal' ;      }   
    elsif($ARGV[0] eq 'search'){       $work_mode = 'search' ;      }   
    elsif($ARGV[0] eq 'list'  ){       $work_mode = 'list' ;        }   
    else {      die "need set work mode! normal/search/list\n ";    }

    my $compiler_range  = "/proj/allproj/Memories_compiler/virage_22ulp_20220121/virage_22nm_range_table/";
    my $compiler_name   = "";
    my $memory_name     = "";
    my $compiler_head   = "";
    my $compiler_type   = "";
    my $nw = "";    my @nw_nb_list;
    my $nb = "";
    my $max_size_nw;
    my $max_size_nb; 
    my $nw_min_abs;
    my $nb_min_abs;
    my $port = "";
    my $pg_enable = 1;
    my $i=0;
    my $j=0;
    my $tcc_goal; my $tcc;

    my $csv_exist=0;
    my $area = 0;
    my $area_csv;

    my $nw_need_split;
    my $nb_need_split;
    my $split_char;

    my @wrapper_list;    
    my @model_list;
    my @wrapper_need_modify;
    my @csv_need_generate;

    if($work_mode eq "list"){
        &get_wrapper_list;
        print "\n";
        my $len = @wrapper_list;
        for($i=0;$i<$len;$i++){

            #---------initial-----------------
            $compiler_name = "";
            $compiler_type = "";
            $compiler_head = "";
            $nw = "";  @nw_nb_list=();
            $nb = "";  
            $port = "";
            $memory_name = "";
            $pg_enable = 1;
            $csv_exist = 0;
            $area = 999999;
            
            $max_size_nw = 0; 
            $max_size_nb = 0;

            $nw_need_split = 1;
            $nb_need_split = 1;

            $nw_min_abs = 99;
            $nb_min_abs = 99;

            my $min_area_memory=0;
            #-----------------------

            # get nw nb port(1p|2p) (cul|dgl|dul|crl..) pg_enable(0|1)
            &mem_match($wrapper_list[$i]);

            # get all possable nw & nb combine (@nw_nb_list), max_size_nw & max_size_nb
            &check_table_range();

            my$len_nw_nb_list = @nw_nb_list;
    
            if($len_nw_nb_list != 0){ # wrapper need not to be spilt
                print"$len_nw_nb_list $wrapper_list[$i] ";
                for($j = 0;$j < $len_nw_nb_list; $j ++){
                    $area_csv = 999999;
                    $csv_exist = 0;
                    
                    my $memory_tmp = "$compiler_head"."$port"."$nw_nb_list[$j]"."m";
                    &check_csv_info($memory_tmp);
                    if($csv_exist == 0){
                        print"$compiler_type $nw_nb_list[$j] need csv! "; 
                        push(@csv_need_generate,"$compiler_type,$port,$nw_nb_list[$j]")
                    }   
                    else{print"$nw_nb_list[$j] "; $min_area_memory = 1;}
                }

                if($min_area_memory == 1){
                    if($tcc =~/tcc/){
                        print" $memory_name $area $tcc\n";
                    }else{
                        push(@model_list,$memory_name);
                        if($wrapper_list[$i] =~ /(\w+_wrapper)/){push(@wrapper_need_modify,"$1,$pg_enable,|$memory_name")}
                        print"$memory_name $area $tcc\n";
                    }
                }else{
                    print" warning! no csv!\n"
                }
            }else{# wrapper need to be spilt
                
                if($wrapper_list[$i] =~ /(\w+_wrapper)/){
                    $split_char = "$1,$pg_enable,";
                }
                if($nw_need_split == 1){&nw_split_process();}
                if($nb_need_split == 1){&nb_split_process();}
                
                &check_table_range();
                my$len_nw_nb_list = @nw_nb_list;
                if($len_nw_nb_list > 0){
                    print"$wrapper_list[$i] need split ";
                    for($j = 0;$j < $len_nw_nb_list; $j ++){
                        $area_csv = 999999;
                        $csv_exist = 0;
                        
                        my $memory_tmp = "$compiler_head"."$port"."$nw_nb_list[$j]"."m";
                        &check_csv_info($memory_tmp);
                        if($csv_exist == 0){
                            print"$compiler_type $nw_nb_list[$j] need csv! "; 
                            push(@csv_need_generate,"$compiler_type,$port,$nw_nb_list[$j]")
                        }   
                        else{print"$nw_nb_list[$j] "; $min_area_memory = 1;}
                    }

                    if($min_area_memory == 1){
                        if($tcc =~/tcc/){
                            print" $memory_name $area $tcc\n";
                        }else{
                            push(@model_list,$memory_name);
                            push(@wrapper_need_modify,"$split_char|$memory_name");
                            print"$memory_name $area $tcc \n";
                        }
                    }else{
                        print"warning! no csv!\n"
                    }
                }else{
                    push(@wrapper_need_modify,"$split_char");
                }
            }
        }

        open WRITE_FILE, ">mem_list.l" or die "can not open mem_list.l";
        foreach(@model_list){
            print WRITE_FILE "$_\n";
        }close WRITE_FILE;

        open WRITE_FILE, ">wrapper_need_modify.l" or die "can not open wrapper_need_modifymem_list.l";
        foreach(@wrapper_need_modify){
            print WRITE_FILE "$_\n";
        }close WRITE_FILE;
        
        open WRITE_FILE, ">module_change_report.csv" or die "can not open module_change_report.csv";
        foreach(@csv_need_generate){
            print WRITE_FILE "$_\n";
        }close WRITE_FILE;

    }

    print"\n";

    #====================================================================================================
    #----------------------------------------------------------------------------------------------------
    # normal mode
    my @log_wrapper_list;
    my $module_inst = "dut";
    my $dff_wrapper_cnt = 0;

    if($work_mode eq "normal"){
        if($ARGV[2]ne""){$module_inst = $ARGV[2]}
        print"process $chip ...\n\n";

        &get_log_wrapper_list();
        &check_log_wrapper_list();
        if($dff_wrapper_cnt == 0){print "there is no dff wrapper in $chip\n"}
    }

    sub check_log_wrapper_list(){
        my $cnt = 0;
        my $len = @log_wrapper_list;
        my $wrapper_path;
        for($i=0;$i<$len;$i++){
            $cnt = 0;
            open READ_FILE,"<$ram_model_file" or die "Can't open $ram_model_file\n";
            while(<READ_FILE>){
                chomp;
                if(/^\/\//){next}
                if(/^\s*$/){next}
                if(/-v\s+(.+\/$log_wrapper_list[$i]\.v)/){
                    $wrapper_path = $1;
                    $wrapper_path =~ s/\$chip/$chip/;
                    $cnt ++;
                }
            }close READ_FILE; 

            if($cnt>1){print"mult time! $log_wrapper_list[$i]\n";}

            open RAM_FILE, "<$wrapper_path" or next;# print "$ram_name does not exist\n";
            while(<RAM_FILE>) {
                chomp;
                if(/^\/\//){next}
                if(/^\s*$/){next}
                if(/define\s+USE_DFF_IMP/){
                    print "DFF $wrapper_path \n";
                    $dff_wrapper_cnt ++;
                }
            }close RAM_FILE;
        }
    }

    sub get_log_wrapper_list(){
        my$log_file = "$chip/top/test/test003/log/verilog.log";
        open READ_FILE,"<$log_file" or die "Can't open $log_file\n";
        while(<READ_FILE>){
            if(/200.*SHOW_RAM_WRAPPER_INSTANTIATION:\s+$module_inst.*\((\w+)\.v\).*PGMEM=(\d)/){
                my $tmp = $1;#print"$tmp\n";
                my $pg_enable= $2;
                if(&count_log_wrapper($tmp)==0){
                    push(@log_wrapper_list,$tmp);
                }
            }
        }close READ_FILE;
    }

    sub count_log_wrapper(){
        my $des = $_[0];
        my $cnt = 0;
        foreach(@log_wrapper_list){
            if($des eq $_){$cnt ++;}
        }
        return $cnt;
    }

    #----------------------------------------------------------------------------------------------------
    #====================================================================================================

    sub get_wrapper_list(){
        my $wrapper_list_path = $ARGV[1] ;#print"$wrapper_list_path\n";
        if($ARGV[2] =~ /(\d)\.(\d+)/){$tcc_goal = $ARGV[2]}
        else{$tcc_goal = 5}
        print"tcc: $tcc_goal\n";
        open READ_FILE, "<$wrapper_list_path",or die"can not open $wrapper_list_path!\n";
        while(<READ_FILE>){
            chomp;
            if(/^\/\//){next;}
            if(/^\s*$/){next;}
            push(@wrapper_list,$_);
        }close READ_FILE;
    }

    sub mem_match(){ 
        my $wrapper_int = $_[0];#$wrapper_list[$i];
        if($wrapper_list[$i]=~/p(\d)/){$pg_enable = $1;} 
        if($wrapper_int=~/dprf_2clk_(\d+)x(\d+).*_wrapper/){
            $compiler_head = "sa"."drl"."$process"."s";
            $compiler_type = "drl";
            $compiler_name = "ts22nuh72p11sadrl128sa07";
            $nw = $1;$nb = $2;if($nb<4){$nb=4}
            $port = "2p";
        }elsif($wrapper_int=~/dprf_1clk_(\d+)x(\d+).*_wrapper/){
            $nw = $1; $nb = $2;$port="2p";
            $compiler_head = "sa"."dul"."$process"."s";
            $compiler_type = "dul";
            if(($nw*$nb)<=(256*1024)){$compiler_name = "ts22nuh72p11sadul128sa06";}
            else{                     $compiler_name = "ts22nuh72p11sadul01msa02p1";}
        }
        elsif($wrapper_int=~/(a55_|a53_|a35_|dos_|)spsram_(\d+)x(\d+).*_wrapper/){
            $nw = $2;#print"$nw\n";
            $nb = $3;#print"$bw\n";
            $port = "1p";
            my $prefix = $1;
            my $size = $nw*$nb;
            if($prefix =~ /(a55_|a53_|a35_)/){
                if($size <= (256*1024)){$compiler_head = "sa"."srl"."$process"."s";$compiler_name = "ts22nuh71p11sasrl128sa05p1";$compiler_type = "srl";}
                else{                   $compiler_head = "sa"."ssl"."$process"."s";$compiler_name = "ts22nuh71p11sassl01msa02p3";$compiler_type = "ssl";}
            }else{                
                if($nw <= 4096){$compiler_head = "sa"."dgl"."$process"."s";$compiler_name = "ts22nuh71p11sadgl128sa05p2";$compiler_type = "dgl";}
                else{                    $compiler_head = "sa"."dul"."$process"."s";$compiler_name = "ts22nuh71p11sadul02msa07p2";$compiler_type = "dul";}
                #$compiler_head = "sa"."dgl"."$process"."s";$compiler_name = "ts22nuh71p11sadgl128sa05p2";$compiler_type = "dgl";#low speed, spsram type choose dgl
            }
        }else{
            die "Error! $wrapper_int wrong sytax!\n";
        }
    }

    #-------------------------------------------------------------------------------------
    # check_table_range to get nw nb combination
    # -------------------------------------------------------------------------------------

    sub check_table_range(){
        my $range_path = "$compiler_range"."$compiler_name";
        my $nw_new ;        my $nb_new ; 
        my $nw_min ;        my $nb_min ;
        my $nw_max ;        my $nb_max ; 
        my $nw_step;        my $nb_step;

        #-------- find out the min nw & min nb
        open READ_FILE, "<$range_path" or die "Can't open $range_path\n";
        while(<READ_FILE>){
            chomp();
            if(/\[(\d+|\d+K)\s+(\d+|\d+K)]%(\d+).*\[(\d+|\d+K)\s+(\d+|\d+K)]%(\d+)/){
                $nw_min  = $1;$nb_min  = $4;  
            }else{next}
            
            if($nw_min =~/(\d+)K/){$nw_min = $1 * 1024} 
            if($nb_min =~/(\d+)K/){$nb_min = $1 * 1024}

            if($nw_min_abs > $nw_min){$nw_min_abs = $nw_min}
            if($nb_min_abs > $nb_min){$nb_min_abs = $nb_min}

        }close READ_FILE; 

        if($nw < $nw_min_abs & $nw>0 ){$nw = $nw_min_abs}
        if($nb < $nb_min_abs & $nb>0 ){$nb = $nb_min_abs}

        #-------- select the possible nw & nb combination

        open READ_FILE, "<$range_path" or die "Can't open $range_path\n";
        while(<READ_FILE>){
            chomp();
            if(/\[(\d+|\d+K)\s+(\d+|\d+K)]%(\d+).*\[(\d+|\d+K)\s+(\d+|\d+K)]%(\d+)/){
                $nw_min  = $1;$nb_min  = $4;  
                $nw_max  = $2;$nb_max  = $5;
                $nw_step = $3;$nb_step = $6;                   
            }else{next}
            
            if($nw_min =~/(\d+)K/){$nw_min = $1 * 1024} if($nb_min =~/(\d+)K/){$nb_min = $1 * 1024}
            if($nw_max =~/(\d+)K/){$nw_max = $1 * 1024} if($nb_max =~/(\d+)K/){$nb_max = $1 * 1024}
            if($nw_step=~/(\d+)K/){$nw_step= $1 * 1024} if($nb_step=~/(\d+)K/){$nb_step= $1 * 1024}

            if($nw<=$nw_max & $nw>=$nw_min & $nb<=$nb_max & $nb>=$nb_min){                
                if($nw%$nw_step!=0){$nw_new=int($nw/$nw_step+1)*$nw_step;}else{$nw_new = $nw}
                if($nb%$nb_step!=0){$nb_new=int($nb/$nb_step+1)*$nb_step;}else{$nb_new = $nb}
                if(&count_nw_nb_list($nw_new,$nb_new)==0){push(@nw_nb_list,"${nw_new}x$nb_new");}
            }elsif($nw<=$nw_max & $nw>=$nw_min & $nb<$nb_min & ($nb_min-$nb)<=$nb_step & $nb>0){
                if($nw%$nw_step!=0){$nw_new=int($nw/$nw_step+1)*$nw_step;}else{$nw_new = $nw}
                $nb_new = $nb_min;
                if(&count_nw_nb_list($nw_new,$nb_new)==0){push(@nw_nb_list,"${nw_new}x$nb_new");}
            }elsif($nw<$nw_min & ($nw_min-$nw)<$nw_step & $nb<=$nb_max & $nb>=$nb_min & $nw>0){
                $nw_new = $nw_min;
                if($nb%$nb_step!=0){$nb_new=int($nb/$nb_step+1)*$nb_step;}else{$nb_new = $nb}
                if(&count_nw_nb_list($nw_new,$nb_new)==0){push(@nw_nb_list,"${nw_new}x$nb_new");}
            }

            #------ find out if the ram need to be split & select the possible max size ram for split

            if($nw<=$nw_max & $nw>=$nw_min & $max_size_nb < $nb_max){
                $max_size_nb = $nb_max;
                $nw_need_split = 0;
                if($nw%$nw_step!=0){
                    $max_size_nw=int($nw/$nw_step+1)*$nw_step;
                }else{$max_size_nw = $nw}
            }

            if($nb<=$nb_max & $nb>=$nb_min & $max_size_nw < $nw_max){
                $max_size_nw = $nw_max;
                $nb_need_split = 0;
                if($nb%$nb_step!=0){
                    $max_size_nb=int($nb/$nb_step+1)*$nb_step;
                }else{$max_size_nb = $nb}
            }
            
        }close READ_FILE;        
    }

    sub count_nw_nb_list(){
        my $des = "$_[0]x$_[1]";
        my $nw_tmp = $_[0];
        my $nb_tmp = $_[1];

        my $cnt = 0;
        foreach(@nw_nb_list){
            if($des eq $_){$cnt ++;}
            if(/(\d+)x(\d+)/){
                if($nb_tmp == $2 & ($nw_tmp-$1)>8){$cnt ++;}
            }
        }
        return $cnt;
    }

    sub check_csv_info(){
        my $grep_mem = "$_[0]";   
        my @grep_csv = `grep -r $grep_mem $csv_lib_path/*.csv`; 
        my $size;
        if($grep_mem =~ /p(\d+x\d+)m/){ $size = $1}
        my $csv_file;
        my $area_index;
        my $memory_name_index;
        my $memory_name_csv;
        my $tcc_index = 99;
        foreach(@grep_csv){
            if($_ =~ /(\w+\.csv):/){
                $csv_exist = 1;
                $csv_file="$csv_lib_path/$1";
                my $grep_csv_file = `grep -r $tcc_corner $csv_file`;
                if($grep_csv_file ne ""){
                    last;
                }
            }
        }

        if($csv_exist == 1 ){
            my $csv_head = `grep -r area $csv_file`;
            my $tcc_csv;
            my @tmp = split (",",$csv_head);
            my $n=0;my $len = @tmp;
            for($n=0;$n<$len;$n++){
                if($tmp[$n]=~/\barea\b/){$area_index = $n;}
                if($tmp[$n]=~/memory_name/){$memory_name_index = $n;}
                if($tmp[$n]=~/$tcc_corner\.Tcc/){$tcc_index = $n}
            }

            my $goal = 0;

            my $periphery_vt_tmp ;
            my $csv_periphery_vt=5;
            open READ_FILE,"<$csv_file" or die "Can't open $ram_model_file\n";
            while(<READ_FILE>){
                chomp;
                if(/sa$compiler_type$process(\w)$port${size}m/){
                    if   ($1 eq "h"){$periphery_vt_tmp = 0}                    
					elsif($1 eq "s"){$periphery_vt_tmp = 1}
                    elsif($1 eq "l"){$periphery_vt_tmp = 2}
                    elsif($1 eq "u"){$periphery_vt_tmp = 3}
                    
                    my @tmp = split (",",$_);
                    if($tcc_index == 99){ # csv missing tcc conner message
                        if ($tmp[$memory_name_index]=~/p${pg_enable}d/ & $tmp[$area_index] <= $area_csv & $csv_periphery_vt >= $periphery_vt_tmp){
                            $area_csv = $tmp[$area_index];
                            $memory_name_csv = $tmp[$memory_name_index];
                            $tcc_csv = "no tcc value!";
                            $goal = 1;
                            $csv_periphery_vt = $periphery_vt_tmp;
                        }
                    }else{
                        if ($tmp[$memory_name_index]=~/p${pg_enable}d/ & $tmp[$area_index] <= $area_csv & $tmp[$tcc_index] < $tcc_goal & $csv_periphery_vt >= $periphery_vt_tmp){
                            $tcc_csv = $tmp[$tcc_index] ;
                            $area_csv = $tmp[$area_index];
                            $memory_name_csv = $tmp[$memory_name_index];
                            $csv_periphery_vt = $periphery_vt_tmp;
                            $goal = 1;
                        }                    
                    }
                }else{
                    next
                }
            }close READ_FILE;
            
            if($area>$area_csv & $goal == 1){$area = $area_csv;$memory_name = $memory_name_csv;$tcc = $tcc_csv}
            elsif($goal == 0){$memory_name = "$grep_mem";$area = "";$tcc = " no tcc match $tcc_goal!";}
        }
    }

    sub nw_split_process(){
        while($nw >= $max_size_nw & $nb <= $max_size_nb & $nb>0){   # $nw need to be split
            print"$wrapper_list[$i] need split ${max_size_nw}x$max_size_nb ";
 
            $csv_exist = 0;
            $area_csv = 999999;

            my $memory_tmp = "$compiler_head"."$port"."${max_size_nw}x$max_size_nb"."m";
                                
            &check_csv_info($memory_tmp);

            if($csv_exist == 0){
                print"$compiler_type ${max_size_nw}x$max_size_nb need csv! \n"; 
                push(@csv_need_generate,"$compiler_type,$port,${max_size_nw}x$max_size_nb");
                $memory_name = "${max_size_nw}x$max_size_nb need csv!";
            }   
            else{ 
                print"$memory_name $area $tcc\n";
                push(@model_list,$memory_name);
            }
            $split_char .= "|$memory_name";
            
            $nw = $nw - $max_size_nw;                    
        }
    }

    sub nb_split_process(){
        while( $nw <= $max_size_nw & $nb >= $max_size_nb & $nw>0){
            print"$wrapper_list[$i] need split ${max_size_nw}x$max_size_nb ";

            $csv_exist = 0;
            $area_csv = 999999;
    
            my $memory_tmp = "$compiler_head"."$port"."${max_size_nw}x$max_size_nb"."m";
                                
            &check_csv_info($memory_tmp);
            
            if($csv_exist == 0){
                print"$compiler_type ${max_size_nw}x$max_size_nb need csv! \n"; 
                push(@csv_need_generate,"$compiler_type,$port,${max_size_nw}x$max_size_nb");
                $memory_name = "${max_size_nw}x$max_size_nb need csv!";
            }   
            else{ 
                print"$memory_name $area $tcc\n";
                push(@model_list,$memory_name);
            }
            $split_char .= "|$memory_name";
            
            $nb = $nb - $max_size_nb;
        } 
    }
