#import "Basic";
#import "Windows"; // Sleep()
#import "Command_Line";

#load "com.jai";

CLI_Arguments :: struct {
    com_port: u8;
    file: string;
};

quit := false;

main :: () {
    if !SetConsoleCtrlHandler(ctrl_handler, 1) {
        log("Unable to set console ctrl handler. Continuing anyways...", flags = .WARNING);
    }
    log("--- ESPFlasher 0.0.1 ---");

    // Parse and validate program arguments
    success, args, is_set := parse_arguments(CLI_Arguments);
    if !success then return;
    if !is_set.com_port {
        log_error("You must provide the com port to flash with the -com_port argument, e.g. '-com_port 3'");

        com_ports := com_query();
        log("Available COM-Ports: %", ifx com_ports then "" else "NONE");
        for com_ports {
            log(" COM-Port %", it);
        }
        return;
    }

    // Open desired com port    
    com, ok := com_init(args.com_port);
    if !ok then return;
    defer com_deinit(com);

    // Reset ESP
    com_rts(com, true);
    Sleep(1000);
    com_rts(com, false);
    Sleep(200);
    com_clear(com);

    while !quit {
        data, ok := com_read(com);
        if !ok then break;
        defer free(data);
        print("%", data);
    }

    log("--- Goodbye ---");
}

ctrl_handler :: (type: u32) {
    quit = true;
}

println :: (format_string: string, args: .. Any, to_standard_error := false) -> bytes_printed: s64 { 
    new_format_string := sprint("%\n", format_string);
    defer free(new_format_string);
    return print(new_format_string, args, to_standard_error = to_standard_error);
} @PrintLike


#run {
    #import "Compiler";
    set_build_options_dc(.{output_executable_name = "espflasher", output_path = "../"});
}