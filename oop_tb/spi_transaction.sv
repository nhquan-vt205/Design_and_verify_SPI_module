class spi_transaction;
    rand logic [7:0] m_data;
    rand logic [7:0] s_data;
    rand logic [2:0] ss_addr;

    // monitor record the result to this two fields
    logic [7:0] m_result;
    logic [7:0] s_result;

    constraint c_addr {
        ss_addr inside {3'd0, 3'd1, 3'd2};
    }

    function new();
        m_data = 0;
        s_data = 0;
        ss_addr = 0;
        m_result = 0;
        s_result = 0;
    endfunction

    function void display(string tag = "");
        $display("%s: m_data = 0x%x, s_data = 0x%x, ss_addr = 0x%x",
                 tag, m_data, s_data, ss_addr);
    endfunction

endclass