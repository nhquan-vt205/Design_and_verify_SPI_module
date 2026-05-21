class spi_generator;
    mailbox #(spi_transaction) gen2drv_mbx;
    int repeat_count = 10;
    
    function new(mailbox #(spi_transaction) mbx, int count = 10);
        gen2drv_mbx = mbx;
        repeat_count = count;
    endfunction

    task run();
        for (int i = 0; i < repeat_count; i++) begin
            spi_transaction trans = new();

            if (!trans.randomize()) begin
                $fatal("[GEN] Randomize failed for trans #%0d", i);
            end 

            trans.display("[GEN]");
            gen2drv_mbx.put(trans);
        end

        $display("[GEN] Done: %0d transactions generated", repeat_count);
    endtask
endclass