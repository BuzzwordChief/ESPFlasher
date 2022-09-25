#import "Basic";
#import "Windows"; // Sleep()

#load "com.jai";

quit := false;

ctrl_handler :: (type: u32) -> void {
    quit = true;
}

main :: () {
    if !SetConsoleCtrlHandler(ctrl_handler, 1) {
        log("Unable to set console ctrl handler. Continuing anyways...");
    }
    log("--- ESPFlasher 0.0.1 ---");

    com, ok := com_init(3);
    if !ok then return;
    defer com_deinit(com);

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

println :: (format_string: string, args: .. Any, to_standard_error := false) -> bytes_printed: s64 { 
    new_format_string := sprint("%\n", format_string);
    defer free(new_format_string);
    return print(new_format_string, args, to_standard_error = to_standard_error);
} @PrintLike