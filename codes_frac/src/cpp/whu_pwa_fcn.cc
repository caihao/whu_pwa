#include "whu_pwa_fcn.h"
#include "whu_constants_and_definitions.h"
#include<sys/time.h>
struct timeval tp;
double start_point,end_point,cpu_time,gpu_time;

#include <cassert>

namespace ROOT {

    namespace Minuit2 {


        double PWAFcn::operator()(const std::vector<double>& par) const {
            assert(par.size() == number_of_parameters_);
            for(int i = 0; i < end_list_index; i++) {
                if (parameter_list_set_[i] == NULL) continue;
                parameter_list_set_[i]->assignment_of_minuit_parameters_from_par(par);
                //parameter_list_set_[i]->shape_of_mapping();
                //parameter_list_set_[i]->shape_of_minuit_parameters();
            }
            gettimeofday(&tp,NULL);
            start_point=tp.tv_sec+tp.tv_usec/1000000.0;
              //parameter_list_set_[phipp_list_index]->assignment_of_minuit_parameters_from_par(par);
            ((CPUWaveFunc*)data_set_[phipp_phsp_index])->cpu_calEva(
                parameter_list_set_[phipp_list_index]->get_minuit_parameters(),
                parameter_list_set_[phipp_list_index]->get_minuit_parameters_back(),
                parameter_list_set_[phipp_list_index]->number_of_amplitudes());
            ((CPUWaveFunc*)data_set_[phipp_data_index])->cpu_calEva(
                parameter_list_set_[phipp_list_index]->get_minuit_parameters(),
                parameter_list_set_[phipp_list_index]->get_minuit_parameters_back(),
                parameter_list_set_[phipp_list_index]->number_of_amplitudes());
            ((CPUWaveFunc*)data_set_[phikk_phsp_index])->cpu_calEva(
                parameter_list_set_[phikk_list_index]->get_minuit_parameters(),
                parameter_list_set_[phikk_list_index]->get_minuit_parameters_back(),
                parameter_list_set_[phikk_list_index]->number_of_amplitudes());
            ((CPUWaveFunc*)data_set_[phikk_data_index])->cpu_calEva(
                parameter_list_set_[phikk_list_index]->get_minuit_parameters(),
                parameter_list_set_[phikk_list_index]->get_minuit_parameters_back(),
                parameter_list_set_[phikk_list_index]->number_of_amplitudes());

            double phsp_phipp, likelihood_phipp, penalty_phipp;
            double phsp_phikk, likelihood_phikk, penalty_phikk;

            phsp_phipp =
                ((CPUWaveFunc*)data_set_[phipp_phsp_index])->sum_phsp(
                    parameter_list_set_[phipp_list_index]->number_of_amplitudes());
            penalty_phipp =
                ((CPUWaveFunc*)data_set_[phipp_phsp_index])->sum_penalty(
                    parameter_list_set_[phipp_list_index]->number_of_amplitudes());

            phsp_phikk =
                ((CPUWaveFunc*)data_set_[phikk_phsp_index])->sum_phsp(
                    parameter_list_set_[phikk_list_index]->number_of_amplitudes());
            penalty_phikk =
                ((CPUWaveFunc*)data_set_[phikk_phsp_index])->sum_penalty(
                    parameter_list_set_[phikk_list_index]->number_of_amplitudes());

            likelihood_phipp =
                ((CPUWaveFunc*)data_set_[phipp_data_index])->sum_likelihood(
                    parameter_list_set_[phipp_list_index]->number_of_amplitudes());
            likelihood_phikk =
                ((CPUWaveFunc*)data_set_[phikk_data_index])->sum_likelihood(
                    parameter_list_set_[phikk_list_index]->number_of_amplitudes());

            gettimeofday(&tp,NULL);
            end_point=tp.tv_sec+tp.tv_usec/1000000.0;
            cpu_time=end_point-start_point;
            //gpu part
            {
            gettimeofday(&tp,NULL);
            start_point=tp.tv_sec+tp.tv_usec/1000000.0;

              (kernel_set_[phipp_phsp_index])->par_trans(
                parameter_list_set_[phipp_list_index]->get_minuit_parameters()
                                                         );
            (kernel_set_[phipp_data_index])->par_trans(
                parameter_list_set_[phipp_list_index]->get_minuit_parameters()
                                                       );
            (kernel_set_[phikk_phsp_index])->par_trans(
                parameter_list_set_[phikk_list_index]->get_minuit_parameters()
                                                       );
            (kernel_set_[phikk_data_index])->par_trans(
                parameter_list_set_[phikk_list_index]->get_minuit_parameters()
                                                       );

            (kernel_set_[phipp_phsp_index])->calEva();
            (kernel_set_[phipp_data_index])->calEva();
            (kernel_set_[phikk_phsp_index])->calEva();
            (kernel_set_[phikk_data_index])->calEva();

            double gpu_phsp_phipp, gpu_likelihood_phipp, gpu_penalty_phipp;
            double gpu_phsp_phikk, gpu_likelihood_phikk, gpu_penalty_phikk;

            gpu_phsp_phipp =
              (kernel_set_[phipp_phsp_index])->sum_phsp();
            gpu_penalty_phipp =
                (kernel_set_[phipp_phsp_index])->sum_penalty();

            gpu_phsp_phikk =
                (kernel_set_[phikk_phsp_index])->sum_phsp();
            gpu_penalty_phikk =
                (kernel_set_[phikk_phsp_index])->sum_penalty();

            gpu_likelihood_phipp =
                (kernel_set_[phipp_data_index])->sum_likelihood();
            gpu_likelihood_phikk =
                (kernel_set_[phikk_data_index])->sum_likelihood();
            
            gettimeofday(&tp,NULL);
            end_point=tp.tv_sec+tp.tv_usec/1000000.0;
            gpu_time=end_point-start_point;

            //message

              cout << "cpu phipp phsp integral = " << phsp_phipp << endl;
              cout << "cpu phipp phsp penalty = " << penalty_phipp << endl;

              cout << " gpu phipp phsp integral = " << gpu_phsp_phipp << endl;
              cout << " gpu phipp phsp penalty = " << gpu_penalty_phipp << endl;

              cout << "cpu phikk phsp integral = " << phsp_phikk << endl;
              cout << "cpu phikk phsp penalty = " << penalty_phikk << endl;
              
              cout << "gpu phikk phsp integral = " << gpu_phsp_phikk << endl;
              cout << "gpu phikk phsp penalty = " << gpu_penalty_phikk << endl;
              
              cout << "cpu phipp data likelihood = " << likelihood_phipp << endl;
              cout << "cpu phikk data likelihood = " << likelihood_phikk << endl;

              cout << "gpu phipp data likelihood = " << gpu_likelihood_phipp << endl;
              cout << "gpu phikk data likelihood = " << gpu_likelihood_phikk << endl;
              cout << "cpu time  : "<<cpu_time<<" s    gpu time  : "<<gpu_time<<" s"<<endl;
            }
                     for(int i = 0; i < end_list_index; i++) {
              if (parameter_list_set_[i] == NULL) continue;
              parameter_list_set_[i]->copy_minuit_parameter_to_back();
              //parameter_list_set_[i]->shape_of_mapping();
              //parameter_list_set_[i]->shape_of_minuit_parameters();
            }

            //double _rec = likelihood_phipp + likelihood_phikk;
            double _rec = - log(phsp_phipp * number_of_events[phipp_data_index] / number_of_events[phipp_phsp_index]) * number_of_events[phipp_data_index] + likelihood_phipp - log(phsp_phikk * number_of_events[phikk_data_index] / number_of_events[phikk_phsp_index]) * number_of_events[phikk_data_index] + likelihood_phikk;
            //double _rec = + log(phsp_phipp) * 1000 + likelihood_phipp + penalty_phipp + log(phsp_phikk) * 100 + likelihood_phikk + penalty_phikk;
            cout << "rec = " << _rec << endl;
            return _rec;
        }


    }  // namespace Minuit2

}  // namespace ROOT
