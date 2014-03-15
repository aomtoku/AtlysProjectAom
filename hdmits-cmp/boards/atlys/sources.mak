BOARD_SRC=$(wildcard $(BOARD_DIR)/top.v)

COMMON_SRC=$(wildcard $(CORES_DIR)/common/rtl/*.v)
GMII_TX_SRC=$(wildcard $(CORES_DIR)/gmii_tx/rtl/*.v)
CRC_SRC=$(wildcard $(CORES_DIR)/crc/rtl/*.v)
GMII2FIFO_SRC=$(wildcard $(CORES_DIR)/gmii2fifo/rtl/*.v)
SYNC_SRC=$(wildcard $(CORES_DIR)/sync/rtl/*.v)
ADPCM_SRC=$(wildcard $(CORES_DIR)/adpcm/rtl/*.v)
TIMING_SRC=$(wildcard $(CORES_DIR)/timing/rtl/*.v)
TMDS_RX_SRC=$(wildcard $(CORES_DIR)/tmds_rx/rtl/*.v)
TMDS_TX_SRC=$(wildcard $(CORES_DIR)/tmds_tx/rtl/*.v)
COREGEN_SRC=$(wildcard $(CORES_DIR)/coregen/*.v)

CORES_SRC=$(COMMON_SRC) $(GMII_TX_SRC) $(CRC_SRC) $(GMII2FIFO_SRC) $(SYNC_SRC) $(ADPCM_SRC) $(TIMING_SRC) $(TMDS_RX_SRC) $(TMDS_TX_SRC) $(COREGEN_SRC)
