#include <cuda_runtime.h>
#include "cuComplex.h"
#include <iostream>
//#include<stdio.h>
#include "cu_PWA_PARAS.h"
#include <vector>
#include <fstream>
#include <math.h>
#include "cu_DPFPropogator.h"
#include "kernel_calEva.h"
#include <assert.h>
#include <vector>
#include "MultDevice.h"
#include <sys/time.h>
using namespace std;

//#ifndef MALLOC_CUDA
//#define MALLOC_CUDA 
//
//    double *d_fx[DEVICE_NUM];
//    int *d_parameter[DEVICE_NUM];
//    double *d_paraList[DEVICE_NUM];
//    double2 * d_complex_para[DEVICE_NUM];
//    double *d_mlk[DEVICE_NUM];
//
//    int tag_cuda;
//#endif
struct timeval tp;

//将任何cuda函数作为CUDA_CALL的参数，能够显示返回的错误，并定位错误。 
#define CUDA_CALL(x) {const cudaError_t a=(x); if(a != cudaSuccess) {printf("\nerror in line:%d CUDAError:%s(err_num=%d)\n",__LINE__,cudaGetErrorString(a),a); cudaDeviceReset(); assert(0); }}
//block_size 的设定要考虑shared memory 的大小
//shared memory per block ：41952 bytes
//每个block所使用的共享空间大小 ：18×int + paraList + 72×BLOCK_SIZE  
//控制BLOCK_SIZE 使所使用的shared memory 不可高于上限
#define BLOCK_SIZE 32


//calEva是在gpu中运行的一个子程序
 __device__ double calEva(const cu_PWA_PARAS *pp, const int * parameter , const double * d_paraList,double *d_mlk,int idp,int offset) 
    ////return square of complex amplitude
{
    //	static int A=0;
    //	A++;
    
    int _N_spinList     =parameter[0];
    int _N_massList     =parameter[1];
    int _N_mass2List    =parameter[2];
    int _N_widthList    =parameter[3];
    int _N_g1List       =parameter[4];
    int _N_g2List       =parameter[5];
    int _N_b1List       =parameter[6];
    int _N_b2List       =parameter[7];
    int _N_b3List       =parameter[8];
    int _N_b4List       =parameter[9];
    int _N_b5List       =parameter[10];
    int _N_rhoList      =parameter[11];
    int _N_fracList     =parameter[12];
    int _N_phiList      =parameter[13];
    int _N_propList     =parameter[14];
    const int const_nAmps=parameter[15];
    double value = 0.;
    //double2 fCF[const_nAmps][4];
    double2 fCF[2]; 
    //double2 (*fCF)[4]=(double2 (*)[4])malloc(sizeof(double2)*const_nAmps*4);
    //double2 fCP[const_nAmps];
    //double2 * fCP=(double2 *)malloc(sizeof(double2)*const_nAmps);
    double2  fCP;
    //double2 * crp1=&complex_para[5*const_nAmps];
    //double2 * crp11=&complex_para[6*const_nAmps];


    //double2 pa[const_nAmps][const_nAmps];
    //double2 * pa=&complex_para[7*const_nAmps];
    //double2 * fu=&complex_para[(7+const_nAmps)*const_nAmps];


    /*double2 **pa,**fu;
    pa=(double2 **)malloc(sizeof(double2 *)*const_nAmps);
    fu=(double2 **)malloc(sizeof(double2 *)*const_nAmps);
    for(int i=0;i<const_nAmps;i++)
    {
        pa[i]=(double2 *)malloc(sizeof(double2)*const_nAmps);
        fu[i]=(double2 *)malloc(sizeof(double2)*const_nAmps);
    }
    //double2 fu[const_nAmps][const_nAmps];
    //double2 crp1[const_nAmps];
    double2 * crp1=(double2 *)malloc(sizeof(double2)*const_nAmps);
    //double2 crp11[const_nAmps];
    double2 * crp11=(double2 *)malloc(sizeof(double2)*const_nAmps);
    */
    double2 cr0p11;
    //double2 ca2p1;
    double2 cw2p11;
    double2 cw2p12;
    double2 cw2p15;
    double2 cw1,cw2,cw3,cw4;
    double2 c1p12_12,c1p13_12,c1p12_13,c1p13_13,c1p12_14,c1p13_14;
    double2 cr1m12_1,cr1m13_1;
    double2 crpf1,crpf2;

    cw1=make_cuDoubleComplex(0.0,0.0);
    cw2=make_cuDoubleComplex(0.0,0.0);
    cw3=make_cuDoubleComplex(0.0,0.0);
    cw4=make_cuDoubleComplex(0.0,0.0);
    for(int index=0; index<const_nAmps; index++) {
        double rho0 = d_paraList[_N_rhoList++];
        double frac0 = d_paraList[_N_fracList++];
        double phi0 = d_paraList[_N_phiList++];
        int spin_now = d_paraList[_N_spinList++];
        int propType_now = d_paraList[_N_propList++];
    //cout<<"haha: "<< __LINE__ << endl;
        double2 crp1,crp11;
        rho0 *= std::exp(frac0);
        fCP=make_cuDoubleComplex(rho0*std::cos(phi0),rho0*std::sin(phi0));
        //        //cout<<"fCP[index]="<<fCP[index]<<endl;
        //std::cout << __FILE__ << __LINE__ << " : " << propType_now << std::endl;
        switch(propType_now)
        {
         //  //cout<<"haha: "<< __LINE__ << endl;
            //                     ordinary  Propagator  Contribution
            case 1:
                {
                    //RooRealVar *width = (RooRealVar*)_widthIterV[omp_id]->Next();
                    double mass0 = d_paraList[_N_massList++];
                    double width0 = d_paraList[_N_widthList++];
                    //					//cout<<"mass0="<<mass0<<endl;
                    //					//cout<<"width0="<<width0<<endl;
                    crp1=propogator(mass0,width0,pp->s23);
                }
                break;
            //	Flatte   Propagator Contribution
            case 2:
                {
                    //RooRealVar *g1 = (RooRealVar*)_g1IterV[omp_id]->Next();
                    //RooRealVar *g2 = (RooRealVar*)_g2IterV[omp_id]->Next();
                    double mass980 = d_paraList[_N_massList++];
                    double g10 = d_paraList[_N_g1List++];
                    double g20 = d_paraList[_N_g2List++];
                    //double g10=g1->getVal();
                    //double g20=g2->getVal();
     //               			//cout<<"mass980="<<mass980<<endl;
     //               			//cout<<"g10="<<g10<<endl;
     //               			//cout<<"g20="<<g20<<endl;
     //                           //cout<<"pp.s23="<<pp.s23<< endl;
                    crp1=propogator980(mass980,g10,g20,pp->s23);
     //               			//cout<<"crp1="<<crp1<<endl;
                }
                break;
                // sigma  Propagator Contribution
            case 3:
                {
                    //RooRealVar *b1 = (RooRealVar*)_b1IterV[omp_id]->Next();
                    //RooRealVar *b2 = (RooRealVar*)_b2IterV[omp_id]->Next();
                    //RooRealVar *b3 = (RooRealVar*)_b3IterV[omp_id]->Next();
                    //RooRealVar *b4 = (RooRealVar*)_b4IterV[omp_id]->Next();
                    //RooRealVar *b5 = (RooRealVar*)_b5IterV[omp_id]->Next();
                    //double mass600=mass->getVal();
                    //double b10=b1->getVal();
                    //double b20=b2->getVal();
                    //double b30=b3->getVal();
                    //double b40=b4->getVal();
                    //double b50=b5->getVal();
                    double mass600 = d_paraList[_N_massList++];
                    double b10 = d_paraList[_N_b1List++];
                    double b20 = d_paraList[_N_b2List++];
                    double b30 = d_paraList[_N_b3List++];
                    double b40 = d_paraList[_N_b4List++];
                    double b50 = d_paraList[_N_b5List++];
                    crp1=propogator600(mass600,b10,b20,b30,b40,b50,pp->s23);
                    //			//cout<<"crp13="<<crp1<<endl;
                }
                break;
                // 1- or 1+  Contribution
            case 4:
                {
                    //RooRealVar *width = (RooRealVar*)_widthIterV[omp_id]->Next();
                    //double mass0=mass->getVal();
                    //double width0=width->getVal();
                    double mass0 = d_paraList[_N_massList++];
                    double width0 = d_paraList[_N_widthList++];
                    crp1=propogator(mass0,width0,pp->sv2);
                    crp11=propogator(mass0,width0,pp->sv3);
                }
                break;
                //  phi(1650) f0(980) include flatte and ordinary Propagator joint Contribution
            case 5:
                {
                    //RooRealVar *mass2  = (RooRealVar*)_mass2IterV[omp_id]->Next();
                    //RooRealVar *g1 = (RooRealVar*)_g1IterV[omp_id]->Next();
                    //RooRealVar *g2 = (RooRealVar*)_g2IterV[omp_id]->Next();
                    //double mass980=mass2->getVal();
                    //double g10=g1->getVal();
                    //double g20=g2->getVal();
                    double mass980 = d_paraList[_N_mass2List++];
                    double g10 = d_paraList[_N_g1List++];
                    double g20 = d_paraList[_N_g2List++];
                    //					//cout<<"mass980="<<mass980<<endl;
                    //					//cout<<"g10="<<g10<<endl;
                    //					//cout<<"g20="<<g20<<endl;
                    crp1=propogator980(mass980,g10,g20,pp->sv);
                    //					//cout<<"crp1="<<crp1<<endl;
                    //RooRealVar *width = (RooRealVar*)_widthIterV[omp_id]->Next();
                    //double mass1680=mass->getVal();
                    //double width1680=width->getVal();
                    double mass1680 = d_paraList[_N_massList++];
                    double width1680 = d_paraList[_N_widthList++];
                    //					//cout<<"mass1680="<<mass1680<<endl;
                    //					//cout<<"width1680="<<width1680<<endl;
                    crp11=propogator(mass1680,width1680,pp->s23);
                    //					//cout<<"crp11="<<crp11<<endl;
                }
                break;
            case 6:
                {
                    //RooRealVar *width = (RooRealVar*)_widthIterV[omp_id]->Next();
                    //double mass0=mass->getVal();
                    //double width0=width->getVal();
                    double mass0 = d_paraList[_N_massList++];
                    double width0 = d_paraList[_N_widthList++];
                    //					//cout<<"mass0="<<mass0<<endl;
                    //					//cout<<"width0="<<width0<<endl;
                    crp1=propogator1270(mass0,width0,pp->s23);
                    //			//cout<<"crp16="<<crp1<<endl;
                }
            default :
                ;
        }
        //if(idp ==1) printf("crp1 : %f\n",cuCreal(crp1));
    //cout << "LINE: " << __LINE__ << endl;
            //if(idp==413) printf("spin_now : %d\n",spin_now);
        for(int i=0;i<2;i++){
            ////cout<<"haha: "<< __LINE__ << endl;
            //		//cout<<"spin_now="<<spin_now<<endl;
            //(idp==413) printf("spin_now : %d\n",spin_now);
            switch(spin_now)
            {
                case 11:
                    //1+_1 contribution
                    //fCF[index][i]=pp.w1p12_1[i]*crp1+pp.w1p13_1[i]*crp11[i];
                    fCF[i]=cuCadd( cuCmuldc(pp->w1p12_1[i],crp1),cuCmuldc(pp->w1p13_1[i],crp11) );

                    break;
                case 12:
                    //1+_2 contribution
                    //c1p12_12=crp1/pp.b2qbv2;
                    c1p12_12=cuCdivcd(crp1,pp->b2qbv2);
                    //c1p13_12=crp11/pp.b2qbv3;
                    c1p13_12=cuCdivcd(crp11,pp->b2qbv3);
                    //fCF[index][i]=pp.w1p12_2[i]*c1p12_12+pp.w1p13_2[i]*c1p13_12;
                    fCF[i]=cuCadd( cuCmuldc(pp->w1p12_2[i],c1p12_12) , cuCmuldc(pp->w1p13_2[i],c1p13_12) );
                
                    break;
                case 13:
                    //1+_3 contribution
                    //c1p12_13=crp1/pp.b2qjv2;
                    c1p12_13=cuCdivcd(crp1,pp->b2qjv2);
                    //c1p13_13=crp11/pp.b2qjv3;
                    c1p13_13=cuCdivcd(crp11,pp->b2qjv3);
                    //fCF[index][i]=pp.w1p12_3[i]*c1p12_13+pp.w1p13_3[i]*c1p13_13;
                    fCF[i]=cuCadd( cuCmuldc(pp->w1p12_3[i],c1p12_13) , cuCmuldc(pp->w1p13_3[i],c1p13_13) );

                    break;
                case 14:
                    //1+_4 contribution
                    //c1p12_12=crp1/pp.b2qbv2;
                    c1p12_12=cuCdivcd(crp1,pp->b2qbv2);
                    
                    c1p13_12=cuCdivcd(crp11,pp->b2qbv3);
                    c1p12_14=cuCdivcd(c1p12_12,pp->b2qjv2);
                    c1p13_14=cuCdivcd(c1p13_12,pp->b2qjv3);
                    fCF[i]=cuCadd( cuCmuldc(pp->w1p12_4[i],c1p12_14), cuCmuldc(pp->w1p13_4[i],c1p13_14));

                    break;
                case 111:
                    //1-__1 contribution
                    cr1m12_1=cuCdivcd( cuCdivcd(crp1,pp->b1qjv2) , pp->b1qbv2);
                    cr1m13_1=cuCdivcd( cuCdivcd(crp11,pp->b1qjv3) , pp->b1qbv3);
                    fCF[i]=cuCadd( cuCmuldc(pp->w1m12[i],cr1m12_1), cuCmuldc(pp->w1m13[i],cr1m13_1));

                    break;
                case 191:
                    //phi(1650)f0(980)_1 contribution
                    //		//cout<<"b1q2r23="<<b1q2r23<<endl;
                    crpf1=cuCdivcd( cuCmul(crp1,crp11),pp->b1q2r23 );
                    //		//cout<<"crpf1="<<crpf1<<endl;
                    fCF[i]=cuCmuldc(pp->ak23w[i],crpf1);
                    //	//cout<<"fCF[index][i]="<<fCF[index][i]<<endl;

                    break;
                case 192:
                    //phi(1650)f0(980)_2 contribution
                    crpf1=cuCdivcd( cuCmul(crp1,crp11) , pp->b1q2r23);
                    crpf2=cuCdivcd(crpf1,pp->b2qjvf2);
                    fCF[i]=cuCmuldc(pp->wpf22[i],crpf2);

                    break;
                case 1:
                    //  //cout<<"haha: "<< __LINE__ << endl;
                    //01 contribution
                    //	//cout<<"wu[i]="<<wu[i]<<endl;
                    //	//cout<<"crp1="<<crp1<<endl;
                    //	//cout<<"index="<<index<<endl;
                    fCF[i]=cuCmuldc(pp->wu[i],crp1);
                    //	//cout<<"fCF[index][i]="<<fCF[index][i]<<endl;
                    //	//cout<<"i="<<i<<endl;

                    break;
                case 2:
                    //02 contribution
                    cr0p11=cuCdivcd(crp1,pp->b2qjvf2);
                    fCF[i]=cuCmuldc(pp->w0p22[i],cr0p11);
                    //	//cout<<"fCF[index][i]02="<<fCF[index][i]<<endl;

                    break;
                case 21:
                    //21 contribution
                    //	//cout<<"b2qf2xx="<<b2qf2xx<<endl;
                    cw2p11=cuCdivcd(crp1,pp->b2qf2xx);
                    //if(idp==413) printf("crp1 : %.10f b2qf2xx : %.10f ",cuCreal(crp1),pp->b2qf2xx);
                    //	//cout<<"cw2p11="<<cw2p11<<endl;
                    //	//cout<<"w2p1[0]="<<w2p1[0]<<endl;
                    //	//cout<<"w2p1[1]="<<w2p1[1]<<endl;
                    fCF[i]=cuCmuldc(pp->w2p1[i],cw2p11);
                    //if(idp == 413) printf("cw2p11 = %.10f fcf = %.10f\n",cuCimag(cw2p11),cuCimag(fCF[i]));
                    //	//cout<<"fCF[index][i]21="<<fCF[index][i]<<endl;

                    break;
                case 22:
                    //22 contribution
                    cw2p11=cuCdivcd(crp1,pp->b2qf2xx);
                    cw2p12=cuCdivcd(cw2p11,pp->b2qjvf2);
                    fCF[i]=cuCmuldc(pp->w2p2[i],cw2p12);

                    break;
                case 23:
                    //23 contribution
                    cw2p11=cuCdivcd(crp1,pp->b2qf2xx);
                    cw2p12=cuCdivcd(cw2p11,pp->b2qjvf2);
                    fCF[i]=cuCmuldc(pp->w2p3[i],cw2p12);

                    break;
                case 24:
                    //24 contribution
                    cw2p11=cuCdivcd(crp1,pp->b2qf2xx);
                    cw2p12=cuCdivcd(cw2p11,pp->b2qjvf2);
                    fCF[i]=cuCmuldc(pp->w2p4[i],cw2p12);

                    break;
                case 25:
                    //25 contribution
                    cw2p11=cuCdivcd(crp1,pp->b2qf2xx);
                    cw2p15=cuCdivcd(cw2p11,pp->b4qjvf2);
                    fCF[i]=cuCmuldc(pp->w2p5[i],cw2p15);

                default:		;
            }
        }
            cw1=cuCadd(cw1,cuCmul(fCP,(fCF[0])));
            cw2=cuCadd(cw2,cuCmul(fCP,(fCF[1])));
            cw3=cuCadd(cw3,cuCmul(cuConj(fCP),cuConj(fCF[0])));
            cw4=cuCadd(cw4,cuCmul(cuConj(fCP),cuConj(fCF[1])));

        double2 cw=cuCmul(fCP,cuConj(fCP));
        double pa=cuCreal(cw);

        cw=make_cuDoubleComplex(0.0,0.0);
        for(int k=0;k<2;k++){
            //cw+=fCF[i][k]*cuConj(fCF[i][k])/(double)2.0;
            cw=cuCadd(cw,cuCdivcd( cuCmul( fCF[k],cuConj(fCF[k]) ),2.0) );
        }
        double fu=cuCreal(cw);
        atomicAdd(d_mlk+index+offset*const_nAmps,pa * fu);
    }
    //#pragmaint  omp parallel for reduction(+:value)

            value = (cuCreal(cuCmul(cw1,cw3))+cuCreal(cuCmul(cw2,cw4)))/2; // Kahan Summation

    /*
    free(fCP);
    for(int i=0;i<const_nAmps;i++)
    {
        free(pa[i]);
        free(fu[i]);
        //free(fCF[i]);
    } 
    free(fCF);
    free(pa);
    free(fu);
    free(crp1);
    free(crp11);
*/
    //if(idp==1) printf("%f %d %f \n", pp->wu[0] ,_N_spinList,d_paraList[0]);
    return (value <= 0) ? 1e-20 : value;
}
__global__ void fx_sum(double *d_fx,double *d_fx_store,int num)
{
    int i = blockDim.x * blockIdx.x + threadIdx.x;
    if(i<num)  atomicAdd(d_fx_store,d_fx[i]);
}
    
__global__ void kernel_store_fx(const double * float_pp,const int *parameter,const double *d_paraList,int para_size,double * d_fx,double *d_mlk,int end,int begin)
{
    int i = blockDim.x * blockIdx.x + threadIdx.x;
    int offset=0;
    //使用shared memory 开辟静态内存
    //int sh_parameter[18];
    __shared__ int sh_parameter[18];
    for(int i=0;i<18;i++)
        sh_parameter[i]=parameter[i];
    //使用shared memory 开辟动态内存
    extern __shared__ double sh_paraList[];
    for(int i=0;i<para_size;i++)
        sh_paraList[i]=d_paraList[i];
        
    double *sh_mlk=&sh_paraList[para_size];
    for(int j=0;j<2*sh_parameter[15];j++)
        sh_mlk[j]=0;
    
    __syncthreads();
    if(i<end-begin && i>= 0)
    {
        int pwa_paras_size = sizeof(cu_PWA_PARAS) / sizeof(double);
        cu_PWA_PARAS  sh_pp;
        for(int j=0;j<pwa_paras_size;j++) 
            *((double*)(&sh_pp)+j)= float_pp[(i+begin)*pwa_paras_size+j];
       /* __shared__ double sh_float_pp[BLOCK_SIZE*72];
        const double *pp = &float_pp[(i+begin)*pwa_paras_size];
        for(int j=0;j<72;j++)
        {
            sh_float_pp[threadIdx.x*72+j]=pp[j];
        }
        cu_PWA_PARAS *sh_pp=(cu_PWA_PARAS*)&sh_float_pp[threadIdx.x*72];*/
        //double2 *complex_para=&d_complex_para[i*6*parameter[15]];
        //将各个参数传到gpu中的内存后，调用子函数calEva 
        //d_fx[i]=calEva(sh_pp,parameter,complex_para,d_paraList,d_mlk,i);
        if(i+begin>=sh_parameter[16])   offset=1;
        d_fx[i]=calEva(&sh_pp,sh_parameter,sh_paraList,sh_mlk,i,offset);
        //printf("%dgpu :: %.7f\n",i,pp->wu[0]);
        //printf("\nfx[%d]:%f\n",i,d_fx[i]);
        //fx[i]=calEva(pp,parameter,d_paraList,i);

    }
        __syncthreads();

        for(int j=0;j<(2*sh_parameter[15]+blockDim.x-1)/blockDim.x;j++)
        {
            if(blockIdx.x+j*blockDim.x<sh_parameter[15])    atomicAdd(&d_mlk[blockIdx.x+j*blockDim.x],sh_mlk[blockIdx.x+j*blockDim.x]);
        }
    //if(i==1)
    //{
        //printf("pp[0]:%f pp[end]:%f parameter[0]:%d parameter[16]:%d paraList[0]:%f \n",float_pp[0],float_pp[end*sizeof(cu_PWA_PARAS)/sizeof(double)-1],parameter[0],parameter[16],d_paraList[0]);
    //}
}
__global__ void reset_mlk(double *d_mlk,double *d_fx_store,int num)
{
    int i = blockDim.x*blockIdx.x+threadIdx.x;
    if(i<num)    d_mlk[i]=0;
    if(i==0)    d_fx_store[0]=0;
}


int cuda_kernel::malloc_mem(int end, int begin, int para_size, int *h_parameter)
{
    int Ns[DEVICE_NUM+1];
    Ns[0]=0;
    for(int i=1;i<DEVICE_NUM;i++)
    {
        Ns[i]=Ns[i-1]+end/DEVICE_NUM;
    }
    Ns[DEVICE_NUM]=end;
    for(int i=0;i<DEVICE_NUM;i++)
    {
        CUDA_CALL( cudaSetDevice(i) );
        int N_thread=Ns[i+1]-Ns[i];
        CUDA_CALL(cudaMalloc((void **)&(d_fx[i]),N_thread * sizeof(double)));
        CUDA_CALL(cudaMalloc((void **)&(d_parameter[i]),18 * sizeof(int)));
        CUDA_CALL(cudaMalloc((void **)&(d_paraList[i]),para_size * sizeof(double)));
        //CUDA_CALL(cudaMalloc( (void**)&d_complex_para[i],6*h_parameter[15]*N_thread *sizeof(double2) ));
        CUDA_CALL(cudaMalloc( (void **)&(d_mlk[i]),(2*h_parameter[15]*sizeof(double) )));
        CUDA_CALL(cudaMalloc( (void **)&(d_fx_store[i]),sizeof(double)));
        h_mlk_pt[i]=(double *)malloc(2*h_parameter[15]*sizeof(double));
    }

    return 0;
}

int cuda_kernel::host_store_fx(vector<double *> d_float_pp,int *h_parameter,double *h_paraList,int para_size, double *h_fx,double * h_mlk,int end,int begini,double *anaint)
{
    //init Ns
    //Ns为分段数组，第i个gpu所处理的线程序号范围为:[ Ns[i] , Ns[i+1] ) 
    int Ns[DEVICE_NUM+1];
    Ns[0]=0;
    for(int i=1;i<DEVICE_NUM;i++)
    {
        Ns[i]=Ns[i-1]+end/DEVICE_NUM;
    }
    Ns[DEVICE_NUM]=end;

    //malloc memory
//    double *d_fx[DEVICE_NUM];
//    int *d_parameter[DEVICE_NUM];
//    double *d_paraList[DEVICE_NUM];
//    double2 * d_complex_para[DEVICE_NUM];
//    double *d_mlk[DEVICE_NUM];
//    for(int i=0;i<DEVICE_NUM;i++)
//    {
//        CUDA_CALL( cudaSetDevice(i) );
//        int N_thread=Ns[i+1]-Ns[i];
//        CUDA_CALL(cudaMalloc((void **)&(d_fx[i]),N_thread * sizeof(double)));
//        CUDA_CALL(cudaMalloc((void **)&(d_parameter[i]),18 * sizeof(int)));
//        CUDA_CALL(cudaMalloc((void **)&(d_paraList[i]),para_size * sizeof(double)));
//        CUDA_CALL(cudaMalloc( (void**)&d_complex_para[i],6*h_parameter[15]*N_thread *sizeof(double2) ));
//        CUDA_CALL(cudaMalloc( (void **)&(d_mlk[i]),(N_thread*h_parameter[15]*sizeof(double) )));
//    }
    //malloc_mem(end, begin, para_size, h_parameter);


    //动态分配shared memory 的大小：
    int size_paraList=(para_size+2*h_parameter[15])*sizeof(double);
    //memcpy d_parameter
    for(int i=0;i<DEVICE_NUM;i++)
    {
        CUDA_CALL(cudaSetDevice(i) );
        //使用异步函数。
        CUDA_CALL(cudaMemcpyAsync(d_parameter[i] , h_parameter, 18*sizeof(int), cudaMemcpyHostToDevice));
    }
    //memcpy d_paraList
    for(int i=0;i<DEVICE_NUM;i++)
    {
        CUDA_CALL(cudaSetDevice(i) );
        //使用异步函数.
        CUDA_CALL(cudaMemcpyAsync(d_paraList[i] , h_paraList, para_size * sizeof(double), cudaMemcpyHostToDevice));
    }
    int threadsPerBlock = BLOCK_SIZE;
    cudaDeviceSynchronize();
    gettimeofday(&tp,NULL);
    double kernel_start=tp.tv_sec+tp.tv_usec/1000000.0;
    for(int i=0;i<DEVICE_NUM;i++)
    {
        CUDA_CALL(cudaSetDevice(i) );
        int N_thread=Ns[i+1]-Ns[i];
        int blocksPerGrid =(N_thread + threadsPerBlock - 1) / threadsPerBlock;
        printf("CUDA kernel launch with %d blocks of %d threads\n", blocksPerGrid, threadsPerBlock);
        reset_mlk<<<(h_parameter[15]+63)/64,64>>>(d_mlk[i],d_fx_store[i],2*h_parameter[15]);
        kernel_store_fx<<<blocksPerGrid, threadsPerBlock,size_paraList>>>(d_float_pp[i], d_parameter[i],d_paraList[i],para_size,d_fx[i],d_mlk[i],Ns[i+1],Ns[i]);
    }
    cudaDeviceSynchronize();
    gettimeofday(&tp,NULL);
    double fx_kstop=tp.tv_sec+tp.tv_usec/1000000.0;
    for(int i=0;i<DEVICE_NUM;i++)
    {
        CUDA_CALL(cudaSetDevice(i) );
        int N_thread=Ns[i+1]-Ns[i];
        int blocksPerGrid =(N_thread + threadsPerBlock - 1) / threadsPerBlock;
        fx_sum<<<blocksPerGrid, threadsPerBlock>>>(d_fx[i],d_fx_store[i],h_parameter[16]-Ns[i]);
    }
    cudaDeviceSynchronize();
    gettimeofday(&tp,NULL);
    double kernel_stop=tp.tv_sec+tp.tv_usec/1000000.0;
    for(int i=0;i<DEVICE_NUM;i++)
    {
        CUDA_CALL(cudaSetDevice(i) );
        int N_thread=Ns[i+1]-Ns[i];
        CUDA_CALL(cudaMemcpyAsync(&h_fx[Ns[i]] , d_fx[i], N_thread * sizeof(double), cudaMemcpyDeviceToHost));
        CUDA_CALL(cudaMemcpyAsync(&h_fx_store[i] , d_fx_store[i], sizeof(double), cudaMemcpyDeviceToHost));
        //CUDA_CALL(cudaMemcpyAsync(&h_mlk[ Ns[i]*h_parameter[15] ] , d_mlk[i], N_thread * h_parameter[15]*sizeof(double), cudaMemcpyDeviceToHost));
    }
    cudaDeviceSynchronize();
    gettimeofday(&tp,NULL);
    double fx_stop=tp.tv_sec+tp.tv_usec/1000000.0;
    for(int i=0;i<DEVICE_NUM;i++)
    {
        CUDA_CALL(cudaSetDevice(i) );
        //CUDA_CALL(cudaMemcpyAsync(&h_fx[Ns[i]] , d_fx[i], N_thread * sizeof(double), cudaMemcpyDeviceToHost));
        CUDA_CALL(cudaMemcpyAsync(h_mlk_pt[i],d_mlk[i],2*h_parameter[15]*sizeof(double), cudaMemcpyDeviceToHost));
    }
    cudaDeviceSynchronize(); 
        for(int j=0;j<2*h_parameter[15];j++)
        {
            h_mlk[j]=0;
        }
        *anaint=0;
    for(int i=0;i<DEVICE_NUM;i++)
    {   
        *anaint+=h_fx_store[i];
        for(int j=0;j<2*h_parameter[15];j++)
        {
            h_mlk[j]+=h_mlk_pt[i][j];
        }
    }
    cout<<"kernel time: "<<kernel_stop-kernel_start<<" S   fx transfer time: "<<fx_stop-kernel_stop<<endl;
    cout<<"fx sum time:"<<kernel_stop-fx_kstop<<" S"<<endl;
    /*cout<<"fx 结果:"<<endl;
    for(int i=0;i<end;i++)
        cout<<h_fx[i]<<"   ";*/
     //free memory
    //CUDA_CALL(cudaFree(d_float_pp));
    //for(int i=0;i<DEVICE_NUM;i++)
    //{
    //    CUDA_CALL(cudaSetDevice(i) );
    //    CUDA_CALL(cudaFree(d_fx[i]));
    //    CUDA_CALL(cudaFree(d_complex_para[i]));
    //    CUDA_CALL(cudaFree(d_parameter[i]));
    //    CUDA_CALL(cudaFree(d_paraList[i]));
    //    CUDA_CALL(cudaFree(d_mlk[i]));
    //}
    //ofstream cout("data_fx_cal");
    //std::cout << __LINE__ << endl;
    //for(int i=begin;i<end;i++)
    //{
        //cout << h_fx[i] << endl;
    //}
    //cout.close();
    return 0;
}
//在gpu中为pwa_paras开辟空间
void cuda_kernel::cu_malloc_h_pp(double *h_float_pp,double *&d_float_pp,int length,int device)
{
    gettimeofday(&tp,NULL);
    double start=tp.tv_sec+tp.tv_usec/1000000.0;
    CUDA_CALL( cudaSetDevice(device) );
    int array_size = sizeof(cu_PWA_PARAS) / sizeof(double) * length;
    int mem_size = array_size * sizeof(double);
    CUDA_CALL(cudaMalloc((void **)&d_float_pp, mem_size));
    cudaDeviceSynchronize();
    gettimeofday(&tp,NULL);
    double malloc=tp.tv_sec+tp.tv_usec/1000000.0;
    CUDA_CALL(cudaMemcpy(d_float_pp , h_float_pp, mem_size, cudaMemcpyHostToDevice));
    cudaDeviceSynchronize();
    gettimeofday(&tp,NULL);
    double stop=tp.tv_sec+tp.tv_usec/1000000.0;
    cout<<"full time:  "<<stop-start<<"  malloc time: "<<malloc-start<<"  memcpy time: "<<stop-malloc<<endl;
}

int cuda_kernel::warp_malloc_mem(int end, int begin, int para_size, int *h_parameter) {

    malloc_mem(end, begin, para_size, h_parameter);

    cout << "test last malloc" << endl;
    cout << d_parameter[0] << endl;
    cout << h_parameter << endl;
    return 0;
}
