SRC = tb_ether.v ../../rtl/gmii_rec.v ../../../crc/rtl/crc_gen.v ../../../gmii_tx/rtl/gmii_tx.v ../../../fifo/test/afifo24.v ../../../fifo/test/asfifo.v ../../../fifo/test/graycounter.v

tb_system: $(SRC)
	iverilog -o tb_system $(SRC)

sim: 
	./tb_system
	gtkwave test.vcd

mem: 
	cd ./gen_mem && gcc gen_amem.c -o gen_amem
	./gen_mem/gen_amem > ./arequest.mem
	cd ./gen_mem && gcc gen_vmem.c -o gen_vmem
	./gen_mem/gen_vmem > ./vrequest.mem

clean: 
	rm -f tb_system verilog.log test.vcd

.PHONY: clean isim wave
