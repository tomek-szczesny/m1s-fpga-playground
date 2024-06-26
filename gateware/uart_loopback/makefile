# Project setup
PROJ=uart_loopback
BUILD_DIR=./build
DEVICE=hx4k
FREQ=1
FOOTPRINT=tq144
PIN_DEF=../ice40_lib/playground.pcf
FILES = $(PROJ).v
# EEPROM size on the dev board, in kB
EEPROM_SIZE=2048
# Remote SBC hostname or IP
REMOTE_HOST=odroidm1s
# Login on remote for one-time setup procedure. Must be a sudoer. 
SETUP_LOGIN=mctom
# Flashrom -p argument
SPI_DEV=/dev/spidev0.0
# Reset Pin: GPIO3B.4 (#108)
RESET_CHIP_DEV=/devices/platform/pinctrl/fe760000.gpio3/gpio/gpiochip96
RESET_LINE=108
# # # # #
# SSH invocation for normal operation (using key and special user account)
SSH=ssh -i ~/.ssh/ice40_prog ice40_prog@$(REMOTE_HOST)
SCP=scp -i ~/.ssh/ice40_prog
PROGRAMMER=linux_spi:dev=$(SPI_DEV),spispeed=20000
PIN_FS=/sys/class/gpio/gpio$(RESET_LINE)
RULE1=SUBSYSTEM==\\\"gpio\\\", DEVPATH==\\\"$(RESET_CHIP_DEV)\\\", ACTION==\\\"add\\\", RUN+=\\\"/bin/sh -c 'echo $(RESET_LINE) > /sys/class/gpio/export'\\\", RUN+=\\\"/bin/chown ice40_prog:ice40_prog $(PIN_FS)/value $(PIN_FS)/direction\\\"
RULE2=SUBSYSTEM==\\\"spidev\\\", GROUP=\\\"ice40_prog\\\", MODE=\\\"0660\\\"

.PHONY: none build burn setup setup_key setup_ssh

none:
	@echo ""
	@echo "make build 		- Builds project"
	@echo "make burn		- Uploads project to a iCE40HX8K-EVB connected to the remote SBC"
	@echo "make reset		- Resets FPGA
	@echo "sudo make setup		- Sets up the local machine and the remote SBC for FPGA programming"

build:
	mkdir -p $(BUILD_DIR)
	yosys -p "synth_ice40 -top top -json $(BUILD_DIR)/$(PROJ).json" $(FILES)
	nextpnr-ice40 --$(DEVICE) --freq $(FREQ) --package $(FOOTPRINT) --json $(BUILD_DIR)/$(PROJ).json \
		      --pcf $(PIN_DEF) --asc $(BUILD_DIR)/$(PROJ).asc --pre-pack $(PROJ).py
	icepack $(BUILD_DIR)/$(PROJ).asc $(BUILD_DIR)/$(PROJ).bin

burn:
	@echo ">>> Padding binary to match EEPROM size..."
	tr '\0' '\377' < /dev/zero | dd bs=1k count=$(EEPROM_SIZE) of=$(BUILD_DIR)/$(PROJ).image
	dd if=$(BUILD_DIR)/$(PROJ).bin conv=notrunc of=$(BUILD_DIR)/$(PROJ).image
	@echo ">>> Copying binary file to the remote host via scp..."
	$(SCP) $(BUILD_DIR)/$(PROJ).image ice40_prog@$(REMOTE_HOST):~/flash.img
	@echo ">>> Asserting reset on FPGA devboard..."
	$(SSH) "echo out > $(PIN_FS)/direction"
	$(SSH) "echo 0 > $(PIN_FS)/value"
	@echo ">>> Flashing devboard EEPROM..."
	-$(SSH) "flashrom -p $(PROGRAMMER) -w ~/flash.img"
	@echo ">>> Releasing reset on FPGA devboard..."
	$(SSH) "echo in > $(PIN_FS)/direction"
	@echo ">>> Removing remote temporary file..."
	$(SSH) "rm ~/flash.img"
	@echo ">>> All done!"

reset:
	@echo ">>> Asserting reset on FPGA devboard..."
	$(SSH) "echo out > $(PIN_FS)/direction"
	$(SSH) "echo 0 > $(PIN_FS)/value"
	@echo ">>> Releasing reset on FPGA devboard..."
	$(SSH) "echo in > $(PIN_FS)/direction"
	@echo ">>> All done!"


setup: | setup_key setup_ssh

setup_key:
	@echo ">>> Generating authentication key to a remote host..."
	ssh-keygen -P "" -f ~/.ssh/ice40_prog

setup_ssh:
	@echo ">>> Connecting to a remote host $(SETUP_LOGIN)@$(REMOTE_HOST)..."
	@ssh $(SETUP_LOGIN)@$(REMOTE_HOST) "sudo -S useradd --create-home ice40_prog || \
		sudo -S mkdir -p /home/ice40_prog/.ssh && \
		echo $(shell cat ~/.ssh/ice40_prog.pub) | sudo -S tee -a /home/ice40_prog/.ssh/authorized_keys > /dev/null && \
		sudo -S chmod 600 /home/ice40_prog/.ssh/authorized_keys && \
		sudo -S chown -R ice40_prog:ice40_prog /home/ice40_prog && \
		echo \"$(RULE1)\" | sudo -S tee /etc/udev/rules.d/99-ice40_prog.rules > /dev/null && \
		echo \"$(RULE2)\" | sudo -S tee -a /etc/udev/rules.d/99-ice40_prog.rules > /dev/null && \
		exit"
	@echo ">>> All set up, please reboot the remote machine."
	@echo ">>> Also, don't forget to turn on SPI on your remote system."
