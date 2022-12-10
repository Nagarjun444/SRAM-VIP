
class  transaction;

  rand bit write,read;
  rand bit [2:0] addres;
  rand bit [7:0] data_in;
        bit [7:0] data_out;
		bit [1:0] cnt;
		
constraint wr_rd_c { write != read; }
				
				
   function void  post_randomize();
    $display("=====TRANSACTIONS ARE GENERATED========="); 
    $display("=====WRITE=%0d======",write  );
	$display("=====READ=%0d=======",read   );
    $display("=====ADRESS=%0d=====",addres );
    $display("=====DATA_IN=%0d====",data_in);
    $display("=====DATA_OUT=%0d===",data_out);	
   endfunction
   
   
   function transaction do_copy();
    transaction trans;
    trans=new();
    trans.write=this.write;
    trans.read=this.read;
    trans.addres=this.addres;
    trans.data_in=this.data_in; 
	return trans;
   endfunction
   
endclass



/////////////generator block///////////////////
class genrator;
 rand transaction trans,tr; 
 int  repeat_count;  //reapeat counter
 
    mailbox gen2driv;  //mailbox created 
  event ended;
  
   function new(mailbox gen2driv,event ended);
     this.gen2driv =gen2driv;
	  this.ended    = ended;
	  trans = new();
  endfunction
     
 task main; 

   repeat(repeat_count) 
     begin
	  if(!trans.randomize())
    	 $fatal("Gen:: trans randomization failed");		
	        tr=trans.do_copy();
	        gen2driv.put(tr);
	     $display("=====TRANSACTIONS PUTING IN TO MAILBOX======");         
     end
	 -> ended; 
 endtask
endclass






//module mailbox_ex;
//   genrator gen;
//   driver   dri;
   
//   mailbox gen2driv;
   
//initial 
 
  //  begin
   //   gen2driv=new();
     // gen =new (gen2driv);
     // dri =new (gen2driv);      
     
   // fork
     //  gen.main();
     // dri.run();
    // join
 //end 
 
 
//endmodule

///////////interface block////////////////////////////////

 interface ram_intf(input logic clk);
   logic write,read;
   logic[2:0] addres;
  logic[7:0] data_in;
  logic[7:0] data_out;
 ////CLOCKING BLOCK///////////////// 
  clocking driver_cb @(posedge clk);
        output write,read;
       output addres;
       output data_in;
       input data_out;        
  endclocking
  clocking  moniter_cb @(posedge clk);
            input write,read;
			input addres;
			input data_in;
			input data_out;
  endclocking 
/////MODPORT BLOCK/////////////////   
   modport drvier_mod( clocking driver_cb,input clk );
   modport moniter_mod( clocking moniter_cb,input clk );
   
endinterface

///////////////DRIVER block////////////////////////////////
`define DRIV_IF ram_vif.drvier_mod.driver_cb
class driver;

  //used to count the number of transactions
  int no_transactions;
  
  virtual ram_intf ram_vif;   
  
    mailbox gen2driv;
	
	function new(virtual ram_intf ram_vif,mailbox gen2driv);
	  this.ram_vif=ram_vif;
	  this.gen2driv=gen2driv;	 
	endfunction
	
	task drive;
			transaction trans;
			 `DRIV_IF.write<=0;
			 `DRIV_IF.read<=0;
			 $display("==========DRIVER IS ENTERD===========");
			gen2driv.get(trans);
			// $display("DRIVER-----TRSFER");
		  @(posedge ram_vif.drvier_mod.clk);
			   	 `DRIV_IF.addres <= trans.addres; 
			if(trans.write)
			  begin 
                 `DRIV_IF.write<=trans.write;
			     `DRIV_IF.data_in<=trans.data_in;
			   // $display("======DRIVER>>>>>>>ADDRES=%0d,DATAIN=%0d======",trans.addres,trans.data_in);
			   @(posedge ram_vif.drvier_mod.clk);
			  end
			if(trans.read)
               begin
			    `DRIV_IF.read<=trans.read; 
				 @(posedge ram_vif.drvier_mod.clk);
			    trans.data_out=`DRIV_IF.data_out;
				// $display("DATA_OUT=%0d",`DRIV_IF.data_out);
			    // $display("======DRIVER>>>>>>>ADDRES=%0d,DATAOUT=%0d======",trans.addres,trans.data_out);
                end
		no_transactions++;
				
	endtask
	
task main;
    //forever 
	 begin
       forever
	      begin
            drive();
		  end
     end
endtask	

   
endclass

////////////////////MONITER/////////////////////
`define  MON_IF  ram_vif.moniter_mod.moniter_cb
class moniter;
 
 virtual ram_intf ram_vif;
 
 mailbox mon2scb;
 
 function new(virtual ram_intf ram_vif,mailbox mon2scb);
           this.ram_vif=ram_vif;
           this.mon2scb=mon2scb;
 endfunction
  
  task main;
       $display("=======MONITER IS ENTERD==========");
     forever 
	   begin
	   
	     transaction trans;		 
		 trans =new();
		 @(posedge ram_vif.clk);
		       trans.addres=`MON_IF.addres;
		    if(ram_vif.write)
			   begin
			     trans.write = `MON_IF.write;
			     trans.data_in=`MON_IF.data_in;
				 // $display("=========MONITER>>>ADRESS=%0d,DATA=%0d========",trans.addres,trans.data_in);
			   end
			 if(ram_vif.read)
			   begin
			     trans.read = `MON_IF.read;
				 trans.data_out=`MON_IF.data_out;	
                 // $display("=========MONITER>>>ADRESS=%0d,DATA=%0d=========",trans.addres,trans.data_out);				 
			   end
	          mon2scb.put(trans);	
             			  
	   end
  
  
  
  
  endtask
endclass
/////////////////////////////////////////

class scroboard;

mailbox mon2scb;


int no_transactions;

bit [7:0] mem[0:7];

bit [7:0]  read_out;


function new(mailbox mon2scb);
    this.mon2scb=mon2scb;	
endfunction

task main;
 transaction trans ;
 forever
 begin
 #100;
	mon2scb.get(trans);      
	 if(trans.read)
	    read_out = mem[trans.addres] ; 		
	 if(trans.write)
        mem[trans.addres] = trans.data_in;
    	
	if(read_out == trans.data_out)
         $display("[SCB-PASS] Addr = %0d,\n  Data :: Expected = %0d Actual = %0d",trans.addres,read_out,trans.data_out);
        else 
         $display("[SCB-FAIL] Addr = %0d,\n  Data :: Expected = %0d Actual = %0d",trans.addres,read_out,trans.data_out);	  
  no_transactions++;
  end
  
endtask
endclass



///////////////////////////////////////////////

//env is create memory 

// // /////////////environment/////////////////
class environment;
   
    genrator gen;
    driver  driv;
	moniter mon;
	scroboard scb;
    mailbox gen2driv;
    mailbox mon2scb;
	
	//event for synchronization between generator and test
  event gen_ended;
   
   virtual ram_intf ram_vif; 
   
   
    function new(virtual ram_intf ram_vif );
	   this.ram_vif = ram_vif;
	   gen2driv =new();
	   mon2scb =new();
	    //creating generator and driver
       gen  = new(gen2driv,gen_ended);
	   driv = new(ram_vif,gen2driv); 
       mon  = new(ram_vif,mon2scb);
       scb  = new(mon2scb);	   
    endfunction
   
   
   task test();
     fork
	   gen.main();
	   driv.main(); // need to check
	   mon.main();
	   scb.main();
	 join_any 
   endtask  
   
   
  task post_test();
    wait(gen_ended.triggered);
    wait(gen.repeat_count == driv.no_transactions);
    wait(gen.repeat_count == scb.no_transactions);
  endtask

  //run task
  task run;
    begin
     test();
     post_test();
     $finish;
	end
  endtask

 endclass

///////////////////TEST/////////////////


program test(ram_intf intf);

class my_trans extends transaction; 
  bit [1:0] count;    
function void pre_randomize();
      write.rand_mode(0);
      read.rand_mode(0);
      addres.rand_mode(0);          
      if(cnt %2 == 0)
       begin
         write = 1;
         read = 0;
         addres  = count;      
       end 
      else
     	begin
         write = 0;
         read = 1;
         addres  = count;
         count++;
      end
      cnt++;
    endfunction
  endclass
  
  environment env;
  my_trans    my_tr;
  initial
    begin
	 env=new(intf);
	 my_tr =new();
     //setting the repeat count of generator as 4, means to generate 4 packets
    env.gen.repeat_count = 12;
	env.gen.trans = my_tr;
	env.run();
	
	end
  
endprogram




module tbench_top;

 bit clk;
 
 always #5 clk =~clk;
 
 ram_intf intf(clk); 
 
 test t1(intf);
 
 ram DUT ( .clk      (intf.clk      ),
		   .write    (intf.write    ),
           .addres   (intf.addres   ),
		   .read     (intf.read     ),
           .data_in  (intf.data_in  ),
           .data_out (intf.data_out ));
	
	
	initial
		begin
			#100000;
			$stop;
		end
	
endmodule

