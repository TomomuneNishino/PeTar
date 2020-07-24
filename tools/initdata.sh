#!/bin/bash

until [[ `echo x$1` == 'x' ]]
do
    case $1 in
	-h) shift;
	    echo 'PeTar initial data file generator, convert input data file to petar input'
	    echo 'input (origin) data file (mass, position[3], velocity[3] per line; 7 columns)';
	    echo 'Usage: petar.init [options] [input data filename]';
	    echo 'Options:';
	    echo '  -f: output file (petar input data) name (default: intput file name + ".input")';
	    echo '  -i: skip rows number (default: 0)';
	    echo '  -s: stellar evolution columns:  base | bse | no (default: no)';
	    echo '  -m: mass scaling factor from input data unit to Msun, used for stellar evolution (BSE): mass[input unit]*m_scale=mass[Msun] (default: 1.0)';
	    echo '  -r: radius scaling factor from input data unit to pc (default: 1.0)';
	    echo '  -u: input data unit is Henon unit, use -m and -r to convert the unit to astronomical unit (Msun, pc, pc/myr)';
	    echo '  -v: if the velocity unit in the input data is [km/s], convert it to [pc/myr]';
	    echo '  -R: initial stellar radius for "-s base" mode (default: 0.0)';
	    exit;;
	-f) shift; fout=$1; shift;;
	-i) shift; igline=$1; shift;;
	-s) shift; seflag=$1; shift;;
	-m) shift; mscale=$1; shift;;
	-r) shift; rscale=$1; shift;;
	-u) convert=1; shift;;
	-R) shift; radius=$1; shift;;
	-v) kms_pcmyr=1; shift;;
	*) fname=$1;shift;;
    esac
done

if [ ! -e $fname ] | [ -z $fname ] ; then
    echo 'Error, file name not provided' 
    exit
fi
[ -z $fout ] && fout=$fname.input
[ -z $igline ] && igline=0
[ -z $seflag ] && seflag=no
[ -z $rscale ] && rscale=1.0
[ -z $mscale ] && mscale=1.0
[ -z $radius ] && radius=0.0
[ -z $convert ] && convert=0
[ -z $kms_pcmyr ] && kms_pcmyr=0

echo 'Transfer "'$fname$'" to PeTar input data file "'$fout'"'
echo 'Skip rows: '$igline
echo 'Add stellar evolution columns: '$seflag

n=`wc -l $fname|cut -d' ' -f1`
n=`expr $n - $igline`

# first, scale data
if [ $convert == 1 ]; then
    echo 'Convert Henon unit to Astronomical unit: distance scale: '$rscale' mass scale: '$mscale' velocity scale: sqrt(G*ms/rs)'
    awk -v ig=$igline -v rs=$rscale -v G=0.00449830997959438 -v ms=$mscale 'BEGIN{vs=sqrt(G*ms/rs)} {OFMT="%.15g"; if(NR>ig) print $1*ms,$2*rs,$3*rs,$4*rs,$5*vs,$6*vs,$7*vs}' $fname >$fout
    mscale=1.0 # use for scaling from Petar unit to stellar evolution unit, since now two units are same, set mscale to 1.0
elif [ $kms_pcmyr == 1 ]; then
    echo 'Convert velocity from km/s to pc/myr'
    awk -v ig=$igline -v vs=1.02269032 '{OFMT="%.15g"; if(NR>ig) print $1,$2,$3,$4,$5*vs,$6*vs,$7*vs}' $fname >$fout
else
    cp $fname $fout
fi
mv $fout $fout.scale__

if [[ $seflag != 'no' ]]; then
    if [[ $seflag == 'base' ]]; then
	echo "Stellar radius (0): " $radius
	awk -v n=$n  'BEGIN{print 0,n,0} {OFMT="%.15g"; print $LINE,0,'$radius',0,0,0,0,NR-ig,0,0,0,0,0,0,0,0,0,0}' $fout.scale__ >$fout
    elif [[ $seflag == 'bse' ]]; then
	echo 'mass scale from PeTar unit (PT) to Msun (m[Msun] = m[PT]*mscale): ' $mscale
	awk -v n=$n -v ms=$mscale  'BEGIN{print 0,n,0} {OFMT="%.15g"; print $LINE, 0,0,0,0,0, 1,$1*ms,$1*ms,0.0,0.0,0.0,0.0,0.0,0.0,0.0, 0.0,NR-ig,0,0,0,0,0,0,0,0,0,0}' $fout.scale__ >$fout
    else
	echo 'Error: unknown option for stellar evolution: '$seflag
    fi
else
    awk -v n=$n 'BEGIN{print 0,n,0} {OFMT="%.15g"; print $LINE, 0,0,NR-ig,0,0,0,0,0,0,0,0,0,0}' $fout.scale__ >$fout
fi
rm -f $fout.scale__
