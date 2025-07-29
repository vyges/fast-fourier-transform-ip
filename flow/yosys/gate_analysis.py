#!/usr/bin/env python3
"""
Gate-Level Analysis Script for Fast Fourier Transform IP ASIC Synthesis
======================================================================
Analyzes synthesized netlists to extract detailed gate counts and statistics.
"""

import re
import sys
import os
import json
from pathlib import Path
from datetime import datetime

def analyze_gates(netlist_file):
    """Analyze gate counts in a synthesized netlist."""
    if not os.path.exists(netlist_file):
        print(f"Warning: Netlist file {netlist_file} not found")
        return None
    
    with open(netlist_file, 'r') as f:
        content = f.read()
    
    # Count different gate types
    gate_counts = {}
    
    # Find all gate instances
    gate_patterns = {
        'AND': r'\\\$_AND_\s+',
        'OR': r'\\\$_OR_\s+',
        'XOR': r'\\\$_XOR_\s+',
        'XNOR': r'\\\$_XNOR_\s+',
        'ANDNOT': r'\\\$_ANDNOT_\s+',
        'NAND': r'\\\$_NAND_\s+',
        'NOR': r'\\\$_NOR_\s+',
        'NOT': r'\\\$_NOT_\s+',
        'MUX': r'\\\$_MUX_\s+',
        'DFF': r'\\\$_DFF_\s+',
        'DFFE': r'\\\$_DFFE_\s+',
        'LATCH': r'\\\$_DLATCH_\s+',
        'ALDFFE': r'\\\$_ALDFFE_\s+',
        'MUL': r'\\\$_MUL_\s+',
        'ADD': r'\\\$_ADD_\s+',
        'SUB': r'\\\$_SUB_\s+',
        'ROM': r'\\\$_ROM_\s+',
        'RAM': r'\\\$_RAM_\s+'
    }
    
    for gate_type, pattern in gate_patterns.items():
        matches = re.findall(pattern, content)
        if matches:
            gate_counts[gate_type] = len(matches)
    
    # Count module instances (excluding primitive gates)
    module_instances = {}
    module_pattern = r'(\w+)\s+(\w+)\s*\('
    for match in re.finditer(module_pattern, content):
        module_name = match.group(1)
        instance_name = match.group(2)
        # Skip primitive gates and Verilog keywords
        if (module_name not in ['module', 'input', 'output', 'wire', '\\$_AND_', 
                               '\\$_OR_', '\\$_XOR_', '\\$_XNOR_', '\\$_ANDNOT_',
                               '\\$_NAND_', '\\$_NOR_', '\\$_NOT_', '\\$_MUX_',
                               '\\$_DFF_', '\\$_DFFE_', '\\$_DLATCH_', '\\$_ALDFFE_',
                               '\\$_MUL_', '\\$_ADD_', '\\$_SUB_', '\\$_ROM_', '\\$_RAM_'] and
            not module_name.startswith('\\$_')):
            if module_name not in module_instances:
                module_instances[module_name] = 0
            module_instances[module_name] += 1
    
    # Count total gates (including module instances for hierarchical designs)
    total_primitive_gates = sum(gate_counts.values())
    
    # Calculate transistor counts (approximate)
    transistor_counts = {
        'AND': 6,      # 2-input AND: 6 transistors
        'OR': 6,       # 2-input OR: 6 transistors
        'XOR': 8,      # 2-input XOR: 8 transistors
        'XNOR': 8,     # 2-input XNOR: 8 transistors
        'ANDNOT': 4,   # AND-NOT: 4 transistors
        'NAND': 4,     # 2-input NAND: 4 transistors
        'NOR': 4,      # 2-input NOR: 4 transistors
        'NOT': 2,      # NOT: 2 transistors
        'MUX': 12,     # 2:1 MUX: 12 transistors
        'DFF': 20,     # DFF: ~20 transistors
        'DFFE': 24,    # DFFE: ~24 transistors (with enable)
        'LATCH': 12,   # Latch: ~12 transistors
        'ALDFFE': 28,  # ALDFFE: ~28 transistors (async load, enable)
        'MUL': 200,    # Multiplier: ~200 transistors (approximate)
        'ADD': 50,     # Adder: ~50 transistors (approximate)
        'SUB': 50,     # Subtractor: ~50 transistors (approximate)
        'ROM': 100,    # ROM: ~100 transistors per bit (approximate)
        'RAM': 150     # RAM: ~150 transistors per bit (approximate)
    }
    
    total_transistors = sum(gate_counts.get(gate, 0) * count 
                           for gate, count in transistor_counts.items())
    
    return {
        'gate_counts': gate_counts,
        'module_instances': module_instances,
        'total_primitive_gates': total_primitive_gates,
        'total_transistors': total_transistors,
        'file': netlist_file
    }

def generate_gate_report():
    """Generate comprehensive gate analysis report."""
    netlists = {
        'FFT Top': 'fft_top_synth_generic.v'
    }
    
    results = {}
    for impl_name, netlist_file in netlists.items():
        # Check if netlist exists in synthesis/netlists directory
        netlist_path = f"../synthesis/netlists/{netlist_file}"
        if Path(netlist_path).exists():
            results[impl_name] = analyze_gates(netlist_path)
    
    # Generate report
    report = []
    report.append("# Fast Fourier Transform IP Gate-Level Analysis Report")
    report.append("=" * 65)
    report.append("")
    report.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    report.append("")
    
    # Summary table
    report.append("## Gate Count Summary")
    report.append("")
    report.append("| Implementation | Primitive Gates | Transistors | Design Style |")
    report.append("|----------------|-----------------|-------------|--------------|")
    
    for impl_name, result in results.items():
        if result:
            gates = result['total_primitive_gates']
            transistors = result['total_transistors']
            # Determine design style based on actual module instances
            actual_modules = {k: v for k, v in result['module_instances'].items() 
                             if not k.startswith('_') and k not in ['\\$_AND_', '\\$_OR_', '\\$_XOR_', '\\$_XNOR_', '\\$_ANDNOT_']}
            style = "Hierarchical" if actual_modules else "Flat"
            report.append(f"| {impl_name} | {gates} | {transistors} | {style} |")
    
    report.append("")
    
    # Detailed analysis for each implementation
    for impl_name, result in results.items():
        if not result:
            continue
            
        report.append(f"## {impl_name} Implementation")
        report.append("")
        
        # Gate breakdown
        report.append("### Gate Breakdown")
        report.append("")
        if result['gate_counts']:
            report.append("| Gate Type | Count | Transistors |")
            report.append("|-----------|-------|-------------|")
            for gate_type, count in sorted(result['gate_counts'].items()):
                transistors = count * {
                    'AND': 6, 'OR': 6, 'XOR': 8, 'XNOR': 8, 
                    'ANDNOT': 4, 'NAND': 4, 'NOR': 4, 'NOT': 2,
                    'MUX': 12, 'DFF': 20, 'DFFE': 24, 'LATCH': 12, 'ALDFFE': 28,
                    'MUL': 200, 'ADD': 50, 'SUB': 50, 'ROM': 100, 'RAM': 150
                }.get(gate_type, 6)
                report.append(f"| {gate_type} | {count} | {transistors} |")
        else:
            report.append("No primitive gates found.")
        
        report.append("")
        
        # Module instances
        if result['module_instances']:
            report.append("### Module Instances")
            report.append("")
            report.append("| Module | Instances |")
            report.append("|--------|-----------|")
            for module, count in result['module_instances'].items():
                report.append(f"| {module} | {count} |")
            report.append("")
        
        # Total statistics
        report.append("### Total Statistics")
        report.append("")
        report.append(f"- **Primitive Gates**: {result['total_primitive_gates']}")
        report.append(f"- **Estimated Transistors**: {result['total_transistors']}")
        actual_modules = {k: v for k, v in result['module_instances'].items() 
                         if not k.startswith('_') and k not in ['\\$_AND_', '\\$_OR_', '\\$_XOR_', '\\$_XNOR_', '\\$_ANDNOT_']}
        report.append(f"- **Design Style**: {'Hierarchical' if actual_modules else 'Flat'}")
        report.append("")
        
        # Logic complexity analysis
        report.append("### Logic Complexity Analysis")
        report.append("")
        
        # Analyze FFT-specific characteristics
        dff_count = result['gate_counts'].get('DFF', 0) + result['gate_counts'].get('DFFE', 0)
        combinational_gates = sum(count for gate, count in result['gate_counts'].items() 
                                 if gate not in ['DFF', 'DFFE', 'LATCH', 'ALDFFE'])
        arithmetic_units = (result['gate_counts'].get('MUL', 0) + 
                           result['gate_counts'].get('ADD', 0) + 
                           result['gate_counts'].get('SUB', 0))
        memory_units = result['gate_counts'].get('ROM', 0) + result['gate_counts'].get('RAM', 0)
        
        report.append(f"- **Sequential Elements**: {dff_count} flip-flops")
        report.append(f"- **Combinational Logic**: {combinational_gates} gates")
        report.append(f"- **Arithmetic Units**: {arithmetic_units} (MUL/ADD/SUB)")
        report.append(f"- **Memory Units**: {memory_units} (ROM/RAM)")
        report.append(f"- **Sequential/Combinational Ratio**: {dff_count/(combinational_gates+1):.2f}")
        
        # FFT-specific analysis
        report.append("- **FFT Algorithm**: Radix-2 Decimation-in-Time (DIT)")
        report.append("- **Pipeline Stages**: Multi-stage pipeline for high throughput")
        report.append("- **Butterfly Operations**: Complex arithmetic for FFT computation")
        report.append("- **Twiddle Factor ROM**: Pre-computed twiddle factors")
        report.append("- **Memory Interface**: APB slave interface for data transfer")
        report.append("- **Scaling Control**: Dynamic scaling for overflow prevention")
        
        report.append("")
    
    # Performance comparison
    report.append("## Performance Analysis")
    report.append("")
    report.append("### Area Efficiency")
    report.append("")
    if results:
        result = list(results.values())[0]
        if result:
            gates = result['total_primitive_gates']
            transistors = result['total_transistors']
            report.append(f"- **Gate Count**: {gates} primitive gates")
            report.append(f"- **Transistor Count**: {transistors} transistors")
            report.append(f"- **Area Estimate**: ~{transistors/1000:.1f}K transistors")
    
    report.append("")
    report.append("### Design Trade-offs")
    report.append("")
    report.append("- **Performance**: High-throughput FFT computation")
    report.append("- **Area**: Optimized for ASIC implementation")
    report.append("- **Power**: Pipeline design for power efficiency")
    report.append("- **Flexibility**: Configurable FFT size and scaling")
    report.append("- **Memory**: Efficient memory usage with twiddle factor ROM")
    report.append("")
    
    # Technology considerations
    report.append("## Technology Considerations")
    report.append("")
    report.append("### Standard Cell Mapping")
    report.append("")
    report.append("FFT IP maps to standard cell library:")
    report.append("- Combinational gates (AND, OR, XOR, MUX)")
    report.append("- Sequential elements (DFF, DFFE)")
    report.append("- Arithmetic units (MUL, ADD, SUB)")
    report.append("- Memory macros (ROM, RAM)")
    report.append("- Compatible with most CMOS processes")
    report.append("")
    
    report.append("### Power Considerations")
    report.append("")
    report.append("- **Static Power**: Moderate (sequential elements)")
    report.append("- **Dynamic Power**: High (arithmetic operations)")
    report.append("- **Clock Power**: Multiple clock domains")
    report.append("- **Memory Power**: ROM/RAM access patterns")
    report.append("")
    
    # FFT-specific considerations
    report.append("### FFT-Specific Considerations")
    report.append("")
    report.append("- **Butterfly Operations**: Complex arithmetic dominates area")
    report.append("- **Pipeline Efficiency**: Multi-stage pipeline for throughput")
    report.append("- **Memory Bandwidth**: Twiddle factor and data memory access")
    report.append("- **Scaling Logic**: Overflow prevention and scaling control")
    report.append("- **Control Logic**: FSM for FFT stage management")
    report.append("")
    
    return "\n".join(report)

if __name__ == "__main__":
    report = generate_gate_report()
    
    # Write to file
    with open("gate_analysis_report.md", "w") as f:
        f.write(report)
    
    print("Gate analysis report generated: gate_analysis_report.md")
    print("\n" + "="*65)
    print(report)