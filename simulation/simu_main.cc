using namespace std;

#include <verilated.h>
#include "verilated_vcd_c.h"
#include "Vsimple_system.h"       //auto created by the verilator from the rtl
#include "Vsimple_system__Dpi.h"   //auto created by the verilator from the rtl

#define CLK_PERIOD          10
#define TCLK_PERIOD         40

int main(int argc,  char ** argv)
{    
    printf("Built with %s %s.\n", Verilated::productName(),           
    Verilated::productVersion());
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    Verilated::debug(0);
    Verilated::randReset(2);
    Verilated::mkdir("./log");
    Vsimple_system * ptTbTop = new Vsimple_system;
    VerilatedVcdC * m_trace = NULL;
    const char* flag_vcd = Verilated::commandArgsPlusMatch("vcd");
    if (flag_vcd && 0==strcmp(flag_vcd, "+vcd")) 
    {
        Verilated::traceEverOn(true); 
        m_trace = new VerilatedVcdC;
        ptTbTop->trace(m_trace, 1); 
        m_trace->open("./log/tb.vcd");
    }
    FILE * trace_fd = NULL;
    const char* flag_trace = Verilated::commandArgsPlusMatch("trace");
    if (flag_trace && 0==strcmp(flag_trace, "+trace")) 
    {
        trace_fd = fopen("./log/tb.trace", "w");
    }
    int m_cpu_tickcount = 0;
    printf("load vmem file (%s) into memory \n", argv[1]);
    svSetScope(svGetScopeFromName("TOP.simple_system.data_ram0"));
    simutil_memload(argv[1]);
    while(!contextp->gotFinish())
    {
        if(m_cpu_tickcount<2)
        {
            ptTbTop->n_rst_i = 1;
        }
        else if( (m_cpu_tickcount>=2) && (m_cpu_tickcount<4))
        {
            ptTbTop->n_rst_i = 0; 
        }
        else
        {
            if(ptTbTop->n_rst_i == 0)
                printf("reset the cpu,done \n");
            ptTbTop->n_rst_i = 1;
        }
        ptTbTop->clk_i = 1;
        ptTbTop->eval();
        if(m_trace)
        {
	        m_trace->dump(m_cpu_tickcount*10);   //  Tick every 10 ns
	    }
        ptTbTop->clk_i = 0;	
        ptTbTop->eval();		  
        if(m_trace)
        {
            m_trace->dump(m_cpu_tickcount*10+5);   // Trailing edge dump
            m_trace->flush();
        }	
        m_cpu_tickcount++;     
    }
    if(m_trace)
    {
        m_trace->flush();
        m_trace->close();
    } 
    if(trace_fd) 
    {
        fflush(trace_fd);
        fclose(trace_fd);
    }
#if VM_COVERAGE
    VerilatedCov::write("log/coverage.dat");
#endif // VM_COVERAGE	
    delete ptTbTop;
    exit(0);
}

