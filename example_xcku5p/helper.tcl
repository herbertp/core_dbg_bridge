# helper.tcl
#	Vivado Helper Procedures
#
# Copyright (C) 2026 H.Poetzl

# Helper procedure to generate or reuse IP
proc generate_ip {ip_name ip_vendor ip_lib ip_version ip_module_name ip_properties} {
    set ip_dir "ip/$ip_module_name"
    set xci_file "$ip_dir/$ip_module_name.xci"
    set dcp_file "$ip_dir/$ip_module_name.dcp"

    set rebuild 0
    set loaded 0
    if {![file exists $xci_file]} {
        set rebuild 1
        puts "IP $ip_module_name: XCI file not found, building..."
    } else {
        if {[catch {read_ip $xci_file} err]} {
            puts "IP $ip_module_name: Error reading $xci_file: $err"
            set rebuild 1
        } else {
            set loaded 1
            set current_ip [get_ips $ip_module_name]
            foreach {prop value} $ip_properties {
                set current_val [get_property $prop $current_ip]
                if {[string compare -nocase $current_val $value] != 0} {
                    set rebuild 1
                    puts "IP $ip_module_name: Property $prop mismatch (current: $current_val, desired: $value), rebuilding..."
                    break
                }
            }
        }
    }

    if {!$rebuild && ![file exists $dcp_file]} {
        set rebuild 1
        puts "IP $ip_module_name: DCP file not found, rebuilding..."
    }

    if {$rebuild} {
        if {$loaded} {
            remove_files [get_files $xci_file]
        }
        if {[file exists $ip_dir]} {
            file delete -force $ip_dir
        }
        if {![file exists ip]} {
            file mkdir ip
        }
        create_ip -name $ip_name -vendor $ip_vendor -library $ip_lib -version $ip_version -module_name $ip_module_name -dir ip
        set_property -dict $ip_properties [get_ips $ip_module_name]
        generate_target all [get_ips $ip_module_name]
        synth_ip [get_ips $ip_module_name]
    } else {
        puts "IP $ip_module_name: Reusing existing build products."
    }
}
