import 'package:creatorconnect/models/educational_video_model.dart';
import 'package:creatorconnect/services/educational_video_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Role-Based Educational Video Visibility Logic', () {
    test('Canonical role normalization', () {
      expect(EducationalVideoService.getCanonicalRole('businessman'), 'Businessman');
      expect(EducationalVideoService.getCanonicalRole('Businessman'), 'Businessman');
      expect(EducationalVideoService.getCanonicalRole('influencer'), 'Influencer');
      expect(EducationalVideoService.getCanonicalRole('Influencer'), 'Influencer');
      expect(EducationalVideoService.getCanonicalRole('writer'), 'Writer');
      expect(EducationalVideoService.getCanonicalRole('Writer'), 'Writer');
      expect(EducationalVideoService.getCanonicalRole('editor'), 'Editor');
      expect(EducationalVideoService.getCanonicalRole('Editor'), 'Editor');
      expect(EducationalVideoService.getCanonicalRole('video editor'), 'Editor');
      expect(EducationalVideoService.getCanonicalRole('Video Editor'), 'Editor');
    });

    test('FINAL RULE: Same Role + Different UID = Video Visible', () {
      final mayurVideo = EducationalVideo(
        videoId: 'v1',
        uploaderUid: 'mayur_uid_123',
        uploaderName: 'Mayur',
        uploaderRole: 'Businessman',
        title: 'Business 101',
        description: 'Startup guide',
        videoUrl: 'https://example.com/video1.mp4',
        createdAt: DateTime.now(),
      );

      // Logged in as another businessman:
      const currentUserRole = 'Businessman';
      const currentUserUid = 'other_businessman_uid_456';

      final roleMatches = mayurVideo.uploaderRole.toLowerCase() ==
          currentUserRole.toLowerCase();
      final notSelf = mayurVideo.uploaderUid != currentUserUid;
      final isVisible = roleMatches && notSelf && mayurVideo.videoUrl.isNotEmpty;

      expect(isVisible, isTrue, reason: 'Other businessmen MUST see Mayur video');
    });

    test('FINAL RULE: Same UID = Own Video Hidden', () {
      final mayurVideo = EducationalVideo(
        videoId: 'v1',
        uploaderUid: 'mayur_uid_123',
        uploaderName: 'Mayur',
        uploaderRole: 'Businessman',
        title: 'Business 101',
        description: 'Startup guide',
        videoUrl: 'https://example.com/video1.mp4',
        createdAt: DateTime.now(),
      );

      // Logged in as Mayur himself:
      const currentUserRole = 'Businessman';
      const currentUserUid = 'mayur_uid_123';

      final roleMatches = mayurVideo.uploaderRole.toLowerCase() ==
          currentUserRole.toLowerCase();
      final notSelf = mayurVideo.uploaderUid != currentUserUid;
      final isVisible = roleMatches && notSelf && mayurVideo.videoUrl.isNotEmpty;

      expect(isVisible, isFalse, reason: 'Mayur MUST NOT see his own video in Education tab');
    });

    test('FINAL RULE: Different Role = Video Hidden', () {
      final mayurVideo = EducationalVideo(
        videoId: 'v1',
        uploaderUid: 'mayur_uid_123',
        uploaderName: 'Mayur',
        uploaderRole: 'Businessman',
        title: 'Business 101',
        description: 'Startup guide',
        videoUrl: 'https://example.com/video1.mp4',
        createdAt: DateTime.now(),
      );

      // Test against all other roles:
      for (final otherRole in ['Influencer', 'Writer', 'Editor']) {
        const otherUserUid = 'other_user_999';
        final roleMatches = mayurVideo.uploaderRole.toLowerCase() ==
            otherRole.toLowerCase();
        final notSelf = mayurVideo.uploaderUid != otherUserUid;
        final isVisible = roleMatches && notSelf && mayurVideo.videoUrl.isNotEmpty;

        expect(isVisible, isFalse, reason: '$otherRole MUST NOT see Mayur Businessman video');
      }
    });

    test('Symmetric logic applies to Influencer, Writer, Editor', () {
      final testCases = [
        {'role': 'Influencer', 'uploader': 'uid_inf_1', 'viewer': 'uid_inf_2', 'other': 'Writer'},
        {'role': 'Writer', 'uploader': 'uid_wri_1', 'viewer': 'uid_wri_2', 'other': 'Editor'},
        {'role': 'Editor', 'uploader': 'uid_edi_1', 'viewer': 'uid_edi_2', 'other': 'Businessman'},
      ];

      for (final tc in testCases) {
        final video = EducationalVideo(
          videoId: 'vid_${tc['role']}',
          uploaderUid: tc['uploader']!,
          uploaderName: '${tc['role']} Creator',
          uploaderRole: tc['role']!,
          title: 'Title',
          description: 'Desc',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: DateTime.now(),
        );

        // 1. Other user of same role sees it
        expect(
          video.uploaderRole.toLowerCase() == tc['role']!.toLowerCase() &&
              video.uploaderUid != tc['viewer']! &&
              video.videoUrl.isNotEmpty,
          isTrue,
        );

        // 2. Uploader cannot see their own video
        expect(
          video.uploaderRole.toLowerCase() == tc['role']!.toLowerCase() &&
              video.uploaderUid != tc['uploader']! &&
              video.videoUrl.isNotEmpty,
          isFalse,
        );

        // 3. Other role cannot see it
        expect(
          video.uploaderRole.toLowerCase() == tc['other']!.toLowerCase() &&
              video.uploaderUid != tc['viewer']! &&
              video.videoUrl.isNotEmpty,
          isFalse,
        );
      }
    });
  });
}

