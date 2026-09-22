// A04 — blocking is instant, reporting is not, and a queued report must never
// look successful.
//
// G7 §4 calls the queued-report state "the single most misleading thing this
// group could ship", and G7 Q14 records that the suite has no P2-OFF-A04 row to
// catch it. This file is that coverage.
//
// The figures deliberately differ from the prototype's "2 blocked" and
// "1 - resolved in 40 minutes": a test built on the mockup's own samples passes
// for a constant as happily as for a computation.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/account/domain/safety.dart';

const _self = 'uid-mine';

void main() {
  group('blocking — the protection she gets instantly', () {
    test('works with no signal and takes effect at once', () async {
      // There is no online flag on the block service at all. Blocking is a
      // local write with a deterministic id, so it cannot fail for want of a
      // network.
      final blocks = InMemoryBlockService(selfUid: _self);

      await blocks.block('uid-nada', BlockSource.post);

      expect(blocks.isBlocked('uid-nada'), isTrue);
      expect(blocks.blocks(), hasLength(1));
    });

    test(
      'the document id is the blocked uid, so a replay cannot duplicate',
      () async {
        // Spine C1. Two devices offline blocking the same woman converge on one
        // document rather than two.
        final blocks = InMemoryBlockService(selfUid: _self);

        await blocks.block('uid-nada', BlockSource.post);
        await blocks.block('uid-nada', BlockSource.profile);
        await blocks.block('uid-nada', BlockSource.post);

        expect(blocks.blocks(), hasLength(1));
        expect(blocks.blocks().single.blockedUid, 'uid-nada');
        // Every write was still attempted — idempotence is in the key, not in a
        // caller remembering to check first.
        expect(blocks.writes, hasLength(3));
      },
    );

    test('she cannot block herself', () {
      final blocks = InMemoryBlockService(selfUid: _self);

      expect(
        () => blocks.block(_self, BlockSource.profile),
        throwsA(isA<StateError>()),
        reason: 'the rules refuse blockedUid == uid',
      );
    });

    test('unblocking removes it by the same id', () async {
      final blocks = InMemoryBlockService(selfUid: _self);

      await blocks.block('uid-nada', BlockSource.message);
      await blocks.unblock('uid-nada');

      expect(blocks.isBlocked('uid-nada'), isFalse);
      expect(blocks.blocks(), isEmpty);
    });

    test('the list is counted, never a fixed sample', () async {
      // Five, not the prototype's two.
      final blocks = InMemoryBlockService(selfUid: _self);
      for (final uid in ['a', 'b', 'c', 'd', 'e']) {
        await blocks.block('uid-$uid', BlockSource.safetyCentre);
      }

      expect(blocks.blocks(), hasLength(5));
    });

    test('the page is capped where the rules cap it', () async {
      final blocks = InMemoryBlockService(selfUid: _self);
      for (var i = 0; i < 64; i++) {
        await blocks.block('uid-$i', BlockSource.post);
      }

      expect(blocks.blocks(), hasLength(kBlockPageSize));
      expect(kBlockPageSize, 50);
    });
  });

  group('reporting — queued is not sent, and the hour has not started', () {
    test('filed with no signal, it is queuedLocal with NO server stamp', () async {
      final reports = InMemoryReportService(reporterUid: _self, online: false);

      final report = await reports.file(
        subjectUid: 'uid-nada',
        reason: ReportReason.harassment,
      );

      expect(report.state, ReportState.queuedLocal);
      expect(
        report.createdAt,
        isNull,
        reason:
            'the SLA clock starts at a SERVER-stamped createdAt. Offline there '
            'is no stamp, so there is no time for the hour to have started '
            'from — the same technique DayTotals uses against a countdown.',
      );
      expect(report.hourStarted, isFalse);
    });

    test(
      'a queued report may never be rendered as "a moderator is reading it"',
      () async {
        final reports = InMemoryReportService(
          reporterUid: _self,
          online: false,
        );

        final report = await reports.file(
          subjectUid: 'uid-nada',
          reason: ReportReason.harassment,
        );
        final view = ReportProjection.forReporter(report);

        expect(view.state, ReportState.queuedLocal);
        expect(view.hourStarted, isFalse);
        expect(
          view.mayClaimModeratorReading,
          isFalse,
          reason: 'G7 §4: the one state that must never look successful',
        );
        expect(view.resolvedInMinutes, isNull);
      },
    );

    test('a queued report cannot be constructed WITH a timestamp', () {
      // The structural half. Someone wiring a local clock into the queued state
      // trips an assert rather than shipping a forged hour.
      expect(
        () => Report(
          id: 'report-1',
          subjectUid: 'uid-nada',
          reason: ReportReason.spam,
          state: ReportState.queuedLocal,
          createdAt: DateTime(2026, 9, 19),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('a submitted report cannot be constructed WITHOUT one', () {
      expect(
        () => Report(
          id: 'report-1',
          subjectUid: 'uid-nada',
          reason: ReportReason.spam,
          state: ReportState.submitted,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test(
      'reconnecting sends it, and the stamp is the moment it SENT',
      () async {
        final sentAt = DateTime(2026, 9, 19, 11, 42);
        final reports = InMemoryReportService(
          reporterUid: _self,
          online: false,
          serverNow: sentAt,
        );

        await reports.file(
          subjectUid: 'uid-nada',
          reason: ReportReason.impersonation,
        );
        await reports.goOnline();

        final report = reports.reports().single;
        expect(report.state, ReportState.submitted);
        expect(
          report.createdAt,
          sentAt,
          reason: 'the hour starts when it sends, not when she wrote it',
        );

        final view = ReportProjection.forReporter(report);
        expect(view.hourStarted, isTrue);
        expect(view.mayClaimModeratorReading, isTrue);
      },
    );

    test('filed online, it is submitted and stamped immediately', () async {
      final reports = InMemoryReportService(reporterUid: _self);

      final report = await reports.file(
        subjectUid: 'uid-nada',
        reason: ReportReason.nudity,
      );

      expect(report.state, ReportState.submitted);
      expect(report.hourStarted, isTrue);
    });

    test('she cannot report herself', () {
      final reports = InMemoryReportService(reporterUid: _self);

      expect(
        () => reports.file(subjectUid: _self, reason: ReportReason.other),
        throwsA(isA<StateError>()),
      );
    });

    test('the note is capped where the rules cap it', () {
      final reports = InMemoryReportService(reporterUid: _self);

      expect(
        () => reports.file(
          subjectUid: 'uid-nada',
          reason: ReportReason.other,
          note: 'x' * (kReportNoteMaxLength + 1),
        ),
        throwsA(isA<StateError>()),
      );
      expect(kReportNoteMaxLength, 1000);
    });

    test('every reason matches the enum the security rules accept', () {
      expect(ReportReason.values.map((r) => r.wireName).toList(), [
        'harassment',
        'man_account',
        'nudity',
        'spam',
        'impersonation',
        'self_harm',
        'other',
      ]);
    });
  });

  group('a resolved time is measured or it is absent', () {
    test('"resolved in N minutes" appears only once it is actually closed', () {
      // 17, not the prototype's 40.
      final closed = Report(
        id: 'report-9',
        subjectUid: 'uid-nada',
        reason: ReportReason.harassment,
        state: ReportState.closed,
        createdAt: DateTime(2026, 9, 19, 9),
        firstResponseMins: 17,
        closedAt: DateTime(2026, 9, 19, 9, 17),
      );

      expect(ReportProjection.forReporter(closed).resolvedInMinutes, 17);
    });

    test('an open report states no resolution time at all', () {
      final triaged = Report(
        id: 'report-9',
        subjectUid: 'uid-nada',
        reason: ReportReason.harassment,
        state: ReportState.triaged,
        createdAt: DateTime(2026, 9, 19, 9),
        firstResponseMins: 17,
      );

      expect(
        ReportProjection.forReporter(triaged).resolvedInMinutes,
        isNull,
        reason:
            'a sample figure stated as her fact is the defect PHASE1-FIXES.md '
            '§13 records four times over',
      );
    });
  });

  group('blocking and reporting are different promises', () {
    test('offline, one works completely and the other does not send', () async {
      final blocks = InMemoryBlockService(selfUid: _self);
      final reports = InMemoryReportService(reporterUid: _self, online: false);

      await blocks.block('uid-nada', BlockSource.safetyCentre);
      final report = await reports.file(
        subjectUid: 'uid-nada',
        reason: ReportReason.harassment,
      );

      // A04 must say so in exactly these terms: the protection is immediate,
      // the review is not.
      expect(blocks.isBlocked('uid-nada'), isTrue);
      expect(report.hourStarted, isFalse);
    });
  });
}
