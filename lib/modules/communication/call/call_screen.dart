// lib/modules/communication/call/call_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'call_bloc.dart';
import '../../mushrooms/screens/mushboom_monarto_screen.dart'; // For FarmColors

class CallScreen extends StatelessWidget {
  const CallScreen({super.key});

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CallBloc, CallState>(
      listener: (context, state) {
        if (state is CallEndedState) {
          Navigator.of(context).maybePop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.reason), backgroundColor: Colors.redAccent),
          );
        }
      },
      builder: (context, state) {
        final bloc = context.read<CallBloc>();

        if (state is CallRingingIncomingState) {
          return _buildIncomingCallView(context, bloc, state);
        } else if (state is CallRingingOutgoingState) {
          return _buildOutgoingCallView(context, bloc, state);
        } else if (state is CallConnectedState) {
          return _buildConnectedCallView(context, bloc, state);
        }

        return const Scaffold(
          backgroundColor: Color(0xFF0F172A),
          body: Center(child: CircularProgressIndicator(color: FarmColors.forestGreen)),
        );
      },
    );
  }

  Widget _buildIncomingCallView(BuildContext context, CallBloc bloc, CallRingingIncomingState state) {
    final initial = state.callerName.isNotEmpty ? state.callerName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            CircleAvatar(
              radius: 54,
              backgroundColor: FarmColors.forestGreen.withValues(alpha: 0.2),
              child: CircleAvatar(
                radius: 46,
                backgroundColor: FarmColors.forestGreen,
                child: Text(
                  initial,
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              state.callerName,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Incoming ${state.callType.toUpperCase()} Call...',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Reject Button
                  FloatingActionButton.large(
                    heroTag: 'reject_call',
                    backgroundColor: Colors.redAccent,
                    onPressed: () => bloc.add(RejectCallEvent()),
                    child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 36),
                  ),
                  // Accept Button
                  FloatingActionButton.large(
                    heroTag: 'accept_call',
                    backgroundColor: FarmColors.forestGreen,
                    onPressed: () => bloc.add(AcceptCallEvent()),
                    child: const Icon(Icons.call_rounded, color: Colors.white, size: 36),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutgoingCallView(BuildContext context, CallBloc bloc, CallRingingOutgoingState state) {
    final initial = state.calleeName.isNotEmpty ? state.calleeName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            CircleAvatar(
              radius: 54,
              backgroundColor: Colors.blue.withValues(alpha: 0.2),
              child: CircleAvatar(
                radius: 46,
                backgroundColor: Colors.blue.shade700,
                child: Text(
                  initial,
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              state.calleeName,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'Calling...',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: FloatingActionButton.large(
                heroTag: 'cancel_call',
                backgroundColor: Colors.redAccent,
                onPressed: () => bloc.add(EndCallEvent()),
                child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 36),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedCallView(BuildContext context, CallBloc bloc, CallConnectedState state) {
    final isVideo = state.callType == 'video';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Remote Video Stream / Audio View
          if (isVideo && !state.isCamDisabled)
            Positioned.fill(
              child: RTCVideoView(
                bloc.engine.remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            )
          else
            Positioned.fill(
              child: Container(
                color: const Color(0xFF0F172A),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: FarmColors.forestGreen.withValues(alpha: 0.2),
                        child: Text(
                          state.peerName.isNotEmpty ? state.peerName[0].toUpperCase() : 'U',
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.peerName,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatDuration(state.durationSeconds),
                        style: const TextStyle(fontSize: 16, color: Colors.tealAccent, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Local Video Preview Overlay
          if (isVideo && !state.isCamDisabled)
            Positioned(
              top: 50,
              right: 16,
              width: 110,
              height: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: Colors.black54,
                  child: RTCVideoView(
                    bloc.engine.localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ),

          // Top Header Bar
          Positioned(
            top: 50,
            left: 16,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white),
                  onPressed: () => bloc.add(TogglePIPEvent()),
                  tooltip: 'Minimize call',
                ),
                const SizedBox(width: 8),
                Text(
                  state.peerName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatDuration(state.durationSeconds),
                    style: const TextStyle(fontSize: 12, color: Colors.tealAccent, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Action Bar
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute Mic
                  IconButton(
                    icon: Icon(
                      state.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      color: state.isMuted ? Colors.redAccent : Colors.white,
                    ),
                    onPressed: () => bloc.add(ToggleMicEvent()),
                  ),
                  // Disable Cam
                  if (isVideo)
                    IconButton(
                      icon: Icon(
                        state.isCamDisabled ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                        color: state.isCamDisabled ? Colors.redAccent : Colors.white,
                      ),
                      onPressed: () => bloc.add(ToggleCamEvent()),
                    ),
                  // Switch Cam
                  if (isVideo)
                    IconButton(
                      icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white),
                      onPressed: () => bloc.add(SwitchCamEvent()),
                    ),
                  // Speaker
                  IconButton(
                    icon: Icon(
                      state.isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                      color: state.isSpeakerOn ? Colors.tealAccent : Colors.white,
                    ),
                    onPressed: () => bloc.add(ToggleSpeakerEvent()),
                  ),
                  // End Call Button
                  FloatingActionButton.small(
                    heroTag: 'end_call',
                    backgroundColor: Colors.redAccent,
                    onPressed: () => bloc.add(EndCallEvent()),
                    child: const Icon(Icons.call_end_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
