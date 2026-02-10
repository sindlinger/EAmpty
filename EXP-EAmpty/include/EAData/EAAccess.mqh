#ifndef __EA_OCO_EAACCESS_MQH__
#define __EA_OCO_EAACCESS_MQH__

#include "EAData.mqh"

// map legacy member names to centralized state (no controller/engine)
#define m_cfg EAData::cfg
#define m_log EAData::log
#define m_risk EAData::risk
#define m_exec EAData::exec
#define m_pos EAData::pos
#define m_sig EAData::sig
#define m_slm EAData::slm

#define m_atrtrail_handle EAData::atrtrail_handle
#define m_phase_handle EAData::phase_handle
#define m_pricezz_handle EAData::pricezz_handle
#define m_pricezz_attach_handle EAData::pricezz_attach_handle
#define m_adxw_handle EAData::adxw_handle
#define m_adxw_attach_handle EAData::adxw_attach_handle
#define m_last_signal_bar EAData::last_signal_bar
#define m_last_signal_dir EAData::last_signal_dir
#define m_last_sig_shift EAData::last_sig_shift
#define m_tf EAData::tf

#define m_btick_path EAData::btick_path
#define m_atrtrail_path EAData::atrtrail_path
#define m_phase_path EAData::phase_path
#define m_pricezz_path EAData::pricezz_path
#define m_pricezz_attach_path EAData::pricezz_attach_path
#define m_adxw_path EAData::adxw_path
#define m_btick_loaded EAData::btick_loaded
#define m_atr_loaded EAData::atr_loaded
#define m_phase_loaded EAData::phase_loaded
#define m_pricezz_loaded EAData::pricezz_loaded
#define m_last_cross_bar EAData::last_cross_bar
#define m_last_cross_time EAData::last_cross_time
#define m_last_cross_dir EAData::last_cross_dir
#define m_last_state_bar EAData::last_state_bar
#define m_last_atr_block_bar EAData::last_atr_block_bar
#define m_btick_cross_bar EAData::btick_cross_bar
#define m_btick_cross_time EAData::btick_cross_time
#define m_btick_cross_dir EAData::btick_cross_dir
#define m_consec_buy3 EAData::consec_buy3
#define m_consec_sell3 EAData::consec_sell3
#define m_live_dir EAData::live_dir
#define m_live_bar EAData::live_bar
#define m_live_start EAData::live_start
#define m_last_price_stats_bar EAData::last_price_stats_bar
#define m_pos_ids EAData::pos_ids
#define m_pos_tags EAData::pos_tags

#endif
