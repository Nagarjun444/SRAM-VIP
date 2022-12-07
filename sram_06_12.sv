module ram(clk,addres,data_in,write,read,data_out);

  input clk,write,read;

  input[2:0] addres;

  input[7:0] data_in;

output reg [7:0] data_out;

  reg [7:0] mem [0:7];



always@(posedge clk)

  if(write)
    
      mem[addres]=data_in;
    
always@(posedge clk)
   if(read==0) 
      data_out=mem[addres];
    else 
      data_out=mem[addres];
 


endmodule

