# Remote OpenLane Integration Guide for FFT Developers

## Overview

This guide walks you through the complete process of taking your FFT design from your local development environment to actual silicon using our remote OpenLane server with GF180MCU and Sky130 PDKs.

## Prerequisites

### Local Development Environment
- ✅ FFT RTL code (SystemVerilog)
- ✅ Testbenches and verification
- ✅ Design documentation
- ✅ Git repository with your FFT project

### Remote OpenLane Server
- ✅ OpenLane v1.0.1 installed
- ✅ GF180MCU PDK configured
- ✅ Sky130 PDK configured
- ✅ IHP-SG13G2 PDK configured (bonus)
- ✅ Docker environment ready

## Step-by-Step Workflow

### Step 1: Prepare Your Local FFT Repository

#### 1.1 Verify Your RTL Structure
Ensure your FFT project has the following structure:
```
fast-fourier-transform-ip/
├── rtl/
│   ├── fft_top.sv              # Top-level module
│   ├── fft_control.sv          # Control logic
│   ├── fft_engine.sv           # FFT computation engine
│   ├── memory_interface.sv     # Memory interface
│   ├── rescale_unit.sv         # Rescaling logic
│   ├── scale_factor_tracker.sv # Scale factor tracking
│   └── twiddle_rom.sv          # Twiddle factor ROM
├── tb/                         # Testbenches
├── docs/                       # Documentation
└── flow/
    └── openlane/               # OpenLane integration files
    └── synthesis/               # Synthesis files
        └── twiddle_rom_synth.sv               # Synthesizable ROM

```

#### 1.2 Verify RTL Completeness
Run a quick check to ensure all required files are present:
```bash
cd fast-fourier-transform-ip
ls -la rtl/*.sv
```

Expected files:
- `fft_top.sv`
- `fft_control.sv`
- `fft_engine.sv`
- `memory_interface.sv`
- `rescale_unit.sv`
- `scale_factor_tracker.sv`
- `twiddle_rom.sv`
- `flow/synthesis/twiddle_rom_synth.sv` (moved from rtl/)

#### 1.3 Test Your RTL Locally
Before sending to OpenLane, verify your RTL works:
```bash
# If you have iverilog installed
cd fast-fourier-transform-ip
iverilog -Wall -o fft_test rtl/*.sv tb/*.sv
./fft_test
```

### Step 2: Connect to Remote OpenLane Server

#### 2.1 Get Server Access
You'll need:
- **Server IP/DNS**: The OpenLane server address
- **SSH Key**: Your private key for authentication
- **Username**: Usually `ubuntu`

#### 2.2 Test Connection
```bash
# Test SSH connection
ssh -i ~/.ssh/your_key.pem ubuntu@your-server-ip

# Verify OpenLane is available
ssh -i ~/.ssh/your_key.pem ubuntu@your-server-ip 'ls -la ~/OpenLane'
```

### Step 3: Upload Your FFT Design

#### 3.1 Create Remote Directory
```bash
ssh -i ~/.ssh/your_key.pem ubuntu@your-server-ip 'mkdir -p ~/fft_project'
```

#### 3.2 Upload Your RTL Files
```bash
# Upload RTL files
scp -i ~/.ssh/your_key.pem -r fast-fourier-transform-ip/rtl/ ubuntu@your-server-ip:~/fft_project/

# Upload OpenLane configuration files
scp -i ~/.ssh/your_key.pem -r fast-fourier-transform-ip/flow/openlane/ ubuntu@your-server-ip:~/fft_project/
```

#### 3.3 Verify Upload
```bash
ssh -i ~/.ssh/your_key.pem ubuntu@your-server-ip 'ls -la ~/fft_project/rtl/'
ssh -i ~/.ssh/your_key.pem ubuntu@your-server-ip 'ls -la ~/fft_project/openlane/'
```

### Step 4: Run OpenLane Synthesis

#### 4.1 Test the Integration
First, validate that everything is set up correctly:
```bash
ssh -i ~/.ssh/your_key.pem ubuntu@your-server-ip 'cd ~/fft_project/openlane && ./test_fft_integration.sh'
```

#### 4.2 Run with GF180MCU PDK
```bash
ssh -i ~/.ssh/your_key.pem ubuntu@your-server-ip 'cd ~/fft_project/openlane && ./run_openlane_fft.sh -p gf180mcu -t fft_gf180mcu_v1 -v'
```

#### 4.3 Run with Sky130 PDK
```bash
ssh -i ~/.ssh/your_key.pem ubuntu@your-server-ip 'cd ~/fft_project/openlane && ./run_openlane_fft.sh -p sky130A -t fft_sky130_v1 -v'
```

### Step 5: Monitor Progress

#### 5.1 Check Progress
```bash
# Monitor the OpenLane flow
ssh -i ~/.ssh/your_key.pem ubuntu@your-server-ip 'tail -f ~/fft_project/openlane/designs/fft_top/runs/fft_gf180mcu_v1/logs/synthesis.log'

# Check overall progress
ssh -i ~/.ssh/your_key.pem ubuntu@your-server-ip 'ps aux | grep openlane'
```

#### 5.2 Expected Timeline
- **Synthesis**: 10-30 minutes
- **Floorplanning**: 5-15 minutes
- **Placement**: 15-45 minutes
- **Routing**: 30-90 minutes
- **Total**: 1-3 hours per PDK

### Step 6: Download Results

#### 6.1 Check Completion
```bash
ssh -i ~/.ssh/your_key.pem ubuntu@your-server-ip 'ls -la ~/fft_project/openlane/designs/fft_top/runs/*/results/final/'
```

#### 6.2 Download Generated Files
```bash
# Create local results directory
mkdir -p fft_results/gf180mcu fft_results/sky130

# Download GF180MCU results
scp -i ~/.ssh/your_key.pem -r ubuntu@your-server-ip:~/fft_project/openlane/designs/fft_top/runs/fft_gf180mcu_v1/results/ fft_results/gf180mcu/

# Download Sky130 results
scp -i ~/.ssh/your_key.pem -r ubuntu@your-server-ip:~/fft_project/openlane/designs/fft_top/runs/fft_sky130_v1/results/ fft_results/sky130/

# Download reports
scp -i ~/.ssh/your_key.pem -r ubuntu@your-server-ip:~/fft_project/openlane/designs/fft_top/runs/*/reports/ fft_results/
```

### Step 7: Analyze Results

#### 7.1 Key Files to Review
```bash
# GDS files (for tapeout)
ls -la fft_results/gf180mcu/results/final/gds/
ls -la fft_results/sky130/results/final/gds/

# LEF files (for integration)
ls -la fft_results/gf180mcu/results/final/lef/
ls -la fft_results/sky130/results/final/lef/

# Gate-level netlists
ls -la fft_results/gf180mcu/results/final/verilog/gl/
ls -la fft_results/sky130/results/final/verilog/gl/
```

#### 7.2 Performance Analysis
```bash
# View synthesis reports
cat fft_results/gf180mcu/reports/synthesis/1-synthesis.stat.rpt
cat fft_results/sky130/reports/synthesis/1-synthesis.stat.rpt

# View timing reports
cat fft_results/gf180mcu/reports/synthesis/1-synthesis.timing.rpt
cat fft_results/sky130/reports/synthesis/1-synthesis.timing.rpt
```

### Step 8: Prepare for Tapeout

#### 8.1 Validate Results
```bash
# Check for DRC violations
grep -i "violation" fft_results/*/reports/routing/*.rpt

# Check for LVS errors
grep -i "error" fft_results/*/reports/lvs/*.rpt

# Check timing closure
grep -i "slack" fft_results/*/reports/synthesis/*.rpt
```

#### 8.2 Tapeout Files
For each PDK, you'll have:
- **GDS file**: `fft_top.gds` (for foundry)
- **LEF file**: `fft_top.lef` (for integration)
- **Netlist**: `fft_top.v` (gate-level)
- **Reports**: Complete analysis reports

## PDK-Specific Considerations

### GF180MCU (180nm)
- **Target**: Low-power MCU applications
- **Performance**: 100MHz, 75k gates, 75mW
- **Use Case**: IoT devices, embedded systems
- **Tapeout**: Google/GlobalFoundries shuttle

### Sky130 (130nm)
- **Target**: High-performance applications
- **Performance**: 1GHz, 50k gates, 50mW
- **Use Case**: DSP, general-purpose ASICs
- **Tapeout**: SkyWater Technology shuttle

## Troubleshooting

### Common Issues

#### 1. RTL Synthesis Failures
```bash
# Check RTL syntax
ssh -i ~/.ssh/your_key.pem ubuntu@your-server-ip 'cd ~/fft_project && iverilog -Wall rtl/*.sv'

# Check for missing modules
grep -i "error" ~/fft_project/openlane/designs/fft_top/runs/*/logs/synthesis.log
```

#### 2. Placement/Routing Failures
```bash
# Check die area constraints
cat ~/fft_project/openlane/designs/fft_top/config.tcl | grep DIE_AREA

# Check pin placement
cat ~/fft_project/openlane/designs/fft_top/pin_order.cfg
```

#### 3. Timing Violations
```bash
# Check clock period
cat ~/fft_project/openlane/designs/fft_top/config.tcl | grep CLOCK_PERIOD

# View timing report
cat fft_results/*/reports/synthesis/1-synthesis.timing.rpt
```

### Debug Commands
```bash
# Check OpenLane status
ssh -i ~/.ssh/your_key.pem ubuntu@your-server-ip 'docker ps'

# Check disk space
ssh -i ~/.ssh/your_key.pem ubuntu@your-server-ip 'df -h'

# Check memory usage
ssh -i ~/.ssh/your_key.pem ubuntu@your-server-ip 'free -h'
```

## Cost Considerations

### Server Costs
- **AWS t3.xlarge**: ~$0.17/hour
- **Typical run time**: 1-3 hours per PDK
- **Total cost per run**: $0.17-$0.51 per PDK

### Tapeout Costs
- **GF180MCU shuttle**: Free (Google-sponsored)
- **Sky130 shuttle**: Free (SkyWater-sponsored)
- **Design submission**: Free

## Next Steps After Synthesis

1. **Review Results**: Analyze performance metrics
2. **Optimize Design**: Make adjustments if needed
3. **Submit to Shuttle**: Upload GDS files to foundry
4. **Wait for Silicon**: 3-6 months for fabrication
5. **Test Chips**: Validate functionality on real silicon

## Support

For issues during the process:
1. Check the troubleshooting section above
2. Review OpenLane logs in the `logs/` directory
3. Contact the Vyges development team
4. Consult PDK-specific documentation

## Success Checklist

- [ ] RTL files uploaded to server
- [ ] OpenLane integration test passed
- [ ] GF180MCU synthesis completed
- [ ] Sky130 synthesis completed
- [ ] Results downloaded locally
- [ ] Performance metrics reviewed
- [ ] GDS files ready for tapeout
- [ ] Shuttle submission prepared

---

**Congratulations!** You're now ready to take your FFT design from RTL to actual silicon using our OpenLane infrastructure. 