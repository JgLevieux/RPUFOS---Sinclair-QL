cp x:/RelSQL/boot .
cp x:/RelSQL/prog_bin .

python mdv_tool.py create --output MD.mdv --file boot --file prog_bin

