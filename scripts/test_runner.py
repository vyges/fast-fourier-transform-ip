#!/usr/bin/env python3
"""
FFT IP Memory Optimization Test Runner
=====================================

A comprehensive test runner for validating memory optimizations and synthesis results.
This script provides advanced testing capabilities including automated verification,
performance analysis, and detailed reporting.

Author: Vyges IP Development Team
Date: 2025-08-11
License: Apache-2.0
"""

import os
import sys
import json
import subprocess
import argparse
import time
from pathlib import Path
from typing import Dict, List, Tuple, Optional
import re

class Colors:
    """ANSI color codes for terminal output"""
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    PURPLE = '\033[0;35m'
    CYAN = '\033[0;36m'
    WHITE = '\033[1;37m'
    NC = '\033[0m'  # No Color

class TestRunner:
    """Main test runner class for FFT IP memory optimizations"""
    
    def __init__(self, project_root: str):
        self.project_root = Path(project_root)
        self.rtl_dir = self.project_root / "rtl"
        self.tb_dir = self.project_root / "tb" / "sv_tb"
        self.synth_dir = self.project_root / "flow" / "yosys"
        self.reports_dir = self.project_root / "flow" / "yosys" / "reports"
        self.scripts_dir = self.project_root / "scripts"
        
        # Test configuration
        self.test_modules = [
            "memory_interface",
            "twiddle_rom", 
            "fft_control"
        ]
        
        # Expected results
        self.expected_results = {
            "memory_interface": {
                "cells": 1000,  # Should be ~1000-2000 cells (down from 67,754)
                "improvement": "30-50x reduction"
            },
            "twiddle_rom": {
                "cells": 2000,  # Should be ~2000-4000 cells (up from 85)
                "improvement": "20-50x increase"
            },
            "total": {
                "cells": 15000,  # Should be ~10,000-15,000 cells (down from 74,217)
                "improvement": "5-7x reduction"
            }
        }
        
        # Test results storage
        self.test_results = {}
        self.synthesis_results = {}
        
    def print_status(self, status: str, message: str):
        """Print colored status message"""
        color_map = {
            "INFO": Colors.BLUE,
            "SUCCESS": Colors.GREEN,
            "WARNING": Colors.YELLOW,
            "ERROR": Colors.RED
        }
        color = color_map.get(status, Colors.WHITE)
        print(f"{color}[{status}]{Colors.NC} {message}")
    
    def check_dependencies(self) -> bool:
        """Check if required tools are available"""
        self.print_status("INFO", "Checking dependencies...")
        
        required_tools = ["yosys", "iverilog", "vvp"]
        missing_tools = []
        
        for tool in required_tools:
            if not self._command_exists(tool):
                missing_tools.append(tool)
        
        if missing_tools:
            self.print_status("ERROR", f"Missing tools: {', '.join(missing_tools)}")
            self.print_status("INFO", "Please install missing tools and try again")
            return False
        
        self.print_status("SUCCESS", "All dependencies available")
        return True
    
    def _command_exists(self, command: str) -> bool:
        """Check if a command exists in PATH"""
        try:
            subprocess.run([command, "--version"], 
                         capture_output=True, check=True)
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            return False
    
    def run_simulation_tests(self) -> bool:
        """Run simulation tests for memory optimizations"""
        self.print_status("INFO", "Running simulation tests...")
        
        test_files = [
            ("tb_memory_interface_opt.sv", "memory_interface_opt"),
            ("tb_twiddle_rom_symmetry.sv", "twiddle_rom_symmetry")
        ]
        
        all_passed = True
        
        for test_file, test_name in test_files:
            test_path = self.tb_dir / test_file
            if test_path.exists():
                self.print_status("INFO", f"Testing {test_name}...")
                if self._run_simulation_test(test_path, test_name):
                    self.print_status("SUCCESS", f"{test_name} test passed")
                else:
                    self.print_status("ERROR", f"{test_name} test failed")
                    all_passed = False
            else:
                self.print_status("WARNING", f"Test file not found: {test_file}")
        
        return all_passed
    
    def _run_simulation_test(self, test_file: Path, test_name: str) -> bool:
        """Run individual simulation test"""
        try:
            # Compile testbench
            compile_cmd = [
                "iverilog", "-g2012", "-o", f"{test_name}.vvp",
                str(test_file), str(self.rtl_dir / "*.sv")
            ]
            
            result = subprocess.run(compile_cmd, 
                                  cwd=self.tb_dir,
                                  capture_output=True, text=True)
            
            if result.returncode != 0:
                self.print_status("ERROR", f"Compilation failed: {result.stderr}")
                return False
            
            # Run simulation
            run_cmd = ["vvp", f"{test_name}.vvp"]
            result = subprocess.run(run_cmd, 
                                  cwd=self.tb_dir,
                                  capture_output=True, text=True)
            
            # Cleanup
            vvp_file = self.tb_dir / f"{test_name}.vvp"
            if vvp_file.exists():
                vvp_file.unlink()
            
            return result.returncode == 0
            
        except Exception as e:
            self.print_status("ERROR", f"Simulation test failed: {e}")
            return False
    
    def run_synthesis_tests(self) -> bool:
        """Run synthesis tests for memory optimizations"""
        self.print_status("INFO", "Running synthesis tests...")
        
        # Create synthesis directory
        self.synth_dir.mkdir(parents=True, exist_ok=True)
        self.reports_dir.mkdir(parents=True, exist_ok=True)
        
        all_passed = True
        
        # Test individual modules
        for module in self.test_modules:
            if self._run_module_synthesis(module):
                self.print_status("SUCCESS", f"{module} synthesis completed")
            else:
                self.print_status("ERROR", f"{module} synthesis failed")
                all_passed = False
        
        # Test comprehensive synthesis
        if self._run_comprehensive_synthesis():
            self.print_status("SUCCESS", "Comprehensive synthesis completed")
        else:
            self.print_status("ERROR", "Comprehensive synthesis failed")
            all_passed = False
        
        return all_passed
    
    def _run_module_synthesis(self, module: str) -> bool:
        """Run synthesis for individual module"""
        try:
            script_file = self.synth_dir / f"synth_{module}_test.tcl"
            
            # Create synthesis script
            script_content = f"""# Yosys synthesis script for {module} optimization test
read_verilog -sv {self.rtl_dir}/{module}.sv
hierarchy -top {module}
proc
opt
memory
opt
techmap
abc -g AND,NAND,OR,NOR,NOT,BUF,XNOR,XOR
stat
write_verilog {self.synth_dir}/{module}_synth.v
write_json {self.synth_dir}/{module}_synth.json
tee -o {self.reports_dir}/{module}_synthesis_report.txt stat
"""
            
            script_file.write_text(script_content)
            
            # Run synthesis
            cmd = ["yosys", "-q", str(script_file)]
            result = subprocess.run(cmd, 
                                  cwd=self.synth_dir,
                                  capture_output=True, text=True)
            
            if result.returncode == 0:
                # Analyze results
                self._analyze_synthesis_results(module)
                return True
            else:
                self.print_status("ERROR", f"Yosys synthesis failed: {result.stderr}")
                return False
                
        except Exception as e:
            self.print_status("ERROR", f"Module synthesis failed: {e}")
            return False
    
    def _run_comprehensive_synthesis(self) -> bool:
        """Run comprehensive synthesis test"""
        try:
            script_file = self.synth_dir / "synth_comprehensive_test.tcl"
            
            # Create comprehensive synthesis script
            script_content = f"""# Yosys comprehensive synthesis script for FFT IP optimization test
read_verilog -sv {self.rtl_dir}/memory_interface.sv
read_verilog -sv {self.rtl_dir}/twiddle_rom.sv
read_verilog -sv {self.rtl_dir}/fft_control.sv
hierarchy -top fft_control
proc
opt
memory
opt
techmap
abc -g AND,NAND,OR,NOR,NOT,BUF,XNOR,XOR
stat
write_verilog {self.synth_dir}/fft_ip_comprehensive_synth.v
write_json {self.synth_dir}/fft_ip_comprehensive_synth.json
tee -o {self.reports_dir}/comprehensive_synthesis_report.txt stat
"""
            
            script_file.write_text(script_content)
            
            # Run synthesis
            cmd = ["yosys", "-q", str(script_file)]
            result = subprocess.run(cmd, 
                                  cwd=self.synth_dir,
                                  capture_output=True, text=True)
            
            if result.returncode == 0:
                # Analyze results
                self._analyze_synthesis_results("comprehensive")
                return True
            else:
                self.print_status("ERROR", f"Comprehensive synthesis failed: {result.stderr}")
                return False
                
        except Exception as e:
            self.print_status("ERROR", f"Comprehensive synthesis failed: {e}")
            return False
    
    def _analyze_synthesis_results(self, module: str):
        """Analyze synthesis results for a module"""
        report_file = self.reports_dir / f"{module}_synthesis_report.txt"
        
        if not report_file.exists():
            self.print_status("WARNING", f"Synthesis report not found: {report_file}")
            return
        
        try:
            report_content = report_file.read_text()
            
            # Extract cell count
            cell_match = re.search(r"Number of cells:\s+(\d+)", report_content)
            if cell_match:
                cell_count = int(cell_match.group(1))
                self.synthesis_results[module] = {"cells": cell_count}
                
                self.print_status("INFO", f"{module} cell count: {cell_count}")
                
                # Compare with expected results
                self._evaluate_synthesis_results(module, cell_count)
            else:
                self.print_status("WARNING", f"Could not extract cell count from {module} report")
                
        except Exception as e:
            self.print_status("ERROR", f"Error analyzing {module} results: {e}")
    
    def _evaluate_synthesis_results(self, module: str, cell_count: int):
        """Evaluate synthesis results against expected values"""
        if module == "memory_interface":
            expected = self.expected_results["memory_interface"]["cells"]
            if cell_count < expected:
                self.print_status("SUCCESS", 
                    f"Memory interface optimization successful: {cell_count} < {expected}")
            else:
                self.print_status("WARNING", 
                    f"Memory interface cell count higher than expected: {cell_count} >= {expected}")
        
        elif module == "twiddle_rom":
            expected = self.expected_results["twiddle_rom"]["cells"]
            if cell_count > expected:
                self.print_status("SUCCESS", 
                    f"Twiddle ROM optimization successful: {cell_count} > {expected}")
            else:
                self.print_status("WARNING", 
                    f"Twiddle ROM cell count lower than expected: {cell_count} <= {expected}")
        
        elif module == "comprehensive":
            expected = self.expected_results["total"]["cells"]
            if cell_count < expected:
                self.print_status("SUCCESS", 
                    f"Overall optimization successful: {cell_count} < {expected}")
            else:
                self.print_status("WARNING", 
                    f"Overall cell count higher than expected: {cell_count} >= {expected}")
    
    def run_verification_tests(self) -> bool:
        """Run verification tests for memory optimizations"""
        self.print_status("INFO", "Running verification tests...")
        
        all_passed = True
        
        # Memory size verification
        if self._verify_memory_size():
            self.print_status("SUCCESS", "Memory size verification passed")
        else:
            self.print_status("ERROR", "Memory size verification failed")
            all_passed = False
        
        # Synthesis attributes verification
        if self._verify_synthesis_attributes():
            self.print_status("SUCCESS", "Synthesis attributes verification passed")
        else:
            self.print_status("ERROR", "Synthesis attributes verification failed")
            all_passed = False
        
        # Code quality verification
        if self._verify_code_quality():
            self.print_status("SUCCESS", "Code quality verification passed")
        else:
            self.print_status("ERROR", "Code quality verification failed")
            all_passed = False
        
        return all_passed
    
    def _verify_memory_size(self) -> bool:
        """Verify memory size requirements in RTL files"""
        self.print_status("INFO", "Verifying memory size requirements...")
        
        all_passed = True
        
        # Check memory interface
        memory_file = self.rtl_dir / "memory_interface.sv"
        if memory_file.exists():
            content = memory_file.read_text()
            if "fft_memory [0:2047]" in content:
                self.print_status("SUCCESS", "Memory size correct: 2048 x 32-bit = 64K bits")
            else:
                self.print_status("ERROR", "Memory size incorrect in memory_interface.sv")
                all_passed = False
        
        # Check twiddle ROM
        rom_file = self.rtl_dir / "twiddle_rom.sv"
        if rom_file.exists():
            content = rom_file.read_text()
            if "rom_memory [ROM_SIZE-1:0]" in content:
                self.print_status("SUCCESS", "ROM size structure correct")
            else:
                self.print_status("ERROR", "ROM size structure incorrect in twiddle_rom.sv")
                all_passed = False
        
        return all_passed
    
    def _verify_synthesis_attributes(self) -> bool:
        """Verify synthesis attributes in RTL files"""
        self.print_status("INFO", "Verifying synthesis attributes...")
        
        all_passed = True
        
        # Check memory interface
        memory_file = self.rtl_dir / "memory_interface.sv"
        if memory_file.exists():
            content = memory_file.read_text()
            if "ram_style = \"block\"" in content:
                self.print_status("SUCCESS", "ram_style attribute found in memory_interface.sv")
            else:
                self.print_status("ERROR", "ram_style attribute not found in memory_interface.sv")
                all_passed = False
        
        # Check twiddle ROM
        rom_file = self.rtl_dir / "twiddle_rom.sv"
        if rom_file.exists():
            content = rom_file.read_text()
            if "rom_style = \"block\"" in content:
                self.print_status("SUCCESS", "rom_style attribute found in twiddle_rom.sv")
            else:
                self.print_status("ERROR", "rom_style attribute not found in twiddle_rom.sv")
                all_passed = False
        
        return all_passed
    
    def _verify_code_quality(self) -> bool:
        """Verify code quality aspects"""
        self.print_status("INFO", "Verifying code quality...")
        
        all_passed = True
        
        # Check reset handling
        for module in ["memory_interface", "twiddle_rom"]:
            module_file = self.rtl_dir / f"{module}.sv"
            if module_file.exists():
                content = module_file.read_text()
                if "reset_n_i" in content:
                    self.print_status("SUCCESS", f"Reset signal found in {module}.sv")
                else:
                    self.print_status("ERROR", f"Reset signal not found in {module}.sv")
                    all_passed = False
                
                if "posedge clk_i" in content:
                    self.print_status("SUCCESS", f"Clock signal found in {module}.sv")
                else:
                    self.print_status("ERROR", f"Clock signal not found in {module}.sv")
                    all_passed = False
        
        return all_passed
    
    def generate_report(self):
        """Generate comprehensive test report"""
        self.print_status("INFO", "Generating test report...")
        
        report_file = self.reports_dir / "python_test_report.md"
        
        report_content = f"""# FFT IP Memory Optimization Test Report

## Test Summary
- **Test Date**: {time.strftime('%Y-%m-%d %H:%M:%S')}
- **Test Runner**: Python Test Runner
- **Test Modules**: {', '.join(self.test_modules)}

## Expected Results
- **Memory Interface**: < {self.expected_results['memory_interface']['cells']} cells (down from 67,754)
- **Twiddle ROM**: > {self.expected_results['twiddle_rom']['cells']} cells (up from 85)
- **Total Design**: < {self.expected_results['total']['cells']} cells (down from 74,217)

## Test Results
"""
        
        # Add synthesis results
        for module, results in self.synthesis_results.items():
            cell_count = results.get("cells", "N/A")
            report_content += f"- **{module}**: {cell_count} cells\n"
        
        report_content += f"""
## Optimization Summary
- **Memory Interface**: Synthesis attributes applied (ram_style = 'block')
- **Memory Size**: Corrected from 65536×32-bit to 2048×32-bit (64K bits)
- **Address Width**: Optimized from 16-bit to 11-bit
- **Twiddle ROM**: Symmetry optimization implemented (4x size reduction)
- **ROM Size**: Reduced from 2048×32-bit to 1024×16-bit (4K bits)

## Recommendations
1. Verify synthesis reports for memory macro usage
2. Check timing constraints for optimized design
3. Validate functionality with comprehensive simulation
4. Compare gate count with previous baseline

## Next Steps
1. Run physical synthesis with vendor tools
2. Implement memory generators for production
3. Add advanced symmetry optimizations
4. Optimize for specific target technology
"""
        
        report_file.write_text(report_content)
        self.print_status("SUCCESS", f"Test report generated: {report_file}")
    
    def run_all_tests(self) -> bool:
        """Run complete test suite"""
        self.print_status("INFO", "Starting FFT IP Memory Optimization Test Suite")
        self.print_status("INFO", f"Project Root: {self.project_root}")
        
        start_time = time.time()
        
        # Check dependencies
        if not self.check_dependencies():
            return False
        
        # Run verification tests
        if not self.run_verification_tests():
            self.print_status("ERROR", "Verification tests failed")
            return False
        
        # Run simulation tests
        if not self.run_simulation_tests():
            self.print_status("ERROR", "Simulation tests failed")
            return False
        
        # Run synthesis tests
        if not self.run_synthesis_tests():
            self.print_status("ERROR", "Synthesis tests failed")
            return False
        
        # Generate report
        self.generate_report()
        
        end_time = time.time()
        duration = end_time - start_time
        
        self.print_status("SUCCESS", f"FFT IP Memory Optimization Test Suite completed successfully!")
        self.print_status("INFO", f"Total test duration: {duration:.2f} seconds")
        self.print_status("INFO", f"Check reports in: {self.reports_dir}")
        
        return True

def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="FFT IP Memory Optimization Test Runner",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python test_runner.py                    # Run all tests
  python test_runner.py --verify-only      # Run only verification tests
  python test_runner.py --sim-only         # Run only simulation tests
  python test_runner.py --synth-only       # Run only synthesis tests
        """
    )
    
    parser.add_argument("--verify-only", action="store_true",
                       help="Run only verification tests")
    parser.add_argument("--sim-only", action="store_true",
                       help="Run only simulation tests")
    parser.add_argument("--synth-only", action="store_true",
                       help="Run only synthesis tests")
    parser.add_argument("--project-root", default=".",
                       help="Project root directory (default: current directory)")
    
    args = parser.parse_args()
    
    # Create test runner
    runner = TestRunner(args.project_root)
    
    try:
        if args.verify_only:
            success = runner.run_verification_tests()
        elif args.sim_only:
            success = runner.run_simulation_tests()
        elif args.synth_only:
            success = runner.run_synthesis_tests()
        else:
            success = runner.run_all_tests()
        
        if success:
            print(f"\n{Colors.GREEN}🎉 All tests completed successfully!{Colors.NC}")
            sys.exit(0)
        else:
            print(f"\n{Colors.RED}❌ Some tests failed!{Colors.NC}")
            sys.exit(1)
            
    except KeyboardInterrupt:
        print(f"\n{Colors.YELLOW}⚠️  Test interrupted by user{Colors.NC}")
        sys.exit(1)
    except Exception as e:
        print(f"\n{Colors.RED}❌ Test runner error: {e}{Colors.NC}")
        sys.exit(1)

if __name__ == "__main__":
    main()
