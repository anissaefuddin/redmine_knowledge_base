# frozen_string_literal: true

namespace :redmine do
  namespace :plugins do
    namespace :redmine_knowledge_base do
      desc 'Seed demo Knowledge Base data: HR and PMO categories with sample articles. ' \
           'Pass LOGIN=<username> to attribute articles to a specific user (defaults to the first active admin). Idempotent - re-running skips articles/categories/tags that already exist.'
      task seed_demo: :environment do
        author = ENV['LOGIN'].present? ? User.find_by(login: ENV['LOGIN']) : User.find_by(admin: true, status: 1)
        raise 'No suitable user found. Pass LOGIN=<username> or ensure an active admin exists.' unless author

        puts "Seeding demo Knowledge Base data as #{author.login}..."

        hr = kb_seed_category('HR', 'Kebijakan, SOP, dan panduan seputar Sumber Daya Manusia.')
        pmo = kb_seed_category('PMO', 'Metodologi, template, dan SOP manajemen proyek dari Project Management Office.')

        puts "Category: HR (##{hr.id})"
        kb_seed_article(
          category: hr, author: author, status: 'published',
          title: 'Panduan Onboarding Karyawan Baru',
          tags: %w[Panduan Onboarding],
          content: <<~MD
            # Panduan Onboarding Karyawan Baru

            ## Ringkasan

            Panduan ini menjelaskan tahapan onboarding untuk karyawan baru sejak hari pertama bergabung hingga akhir masa probation.

            ## Sebelum Hari Pertama

            - HR mengirimkan surat penawaran dan kontrak kerja
            - IT menyiapkan akun email, laptop, dan akses sistem
            - Atasan langsung menyiapkan rencana kerja 30-60-90 hari

            ## Hari Pertama

            1. Registrasi ulang data karyawan di sistem HR
            2. Pengenalan tim dan lingkungan kerja
            3. Briefing kebijakan perusahaan (jam kerja, cuti, kode etik)

            ## Minggu Pertama

            - Sesi pengenalan produk/layanan perusahaan
            - Setup akses ke seluruh tools kerja
            - Pertemuan 1-on-1 pertama dengan atasan langsung

            ## Masa Probation (3 Bulan)

            | Periode | Fokus |
            |---|---|
            | Bulan 1 | Adaptasi dan pembelajaran dasar |
            | Bulan 2 | Kontribusi mandiri pada tugas kecil |
            | Bulan 3 | Evaluasi kinerja dan keputusan pengangkatan |

            ## Referensi

            - Kebijakan Work From Home (WFH)
            - SOP Pengajuan Cuti Tahunan
          MD
        )

        kb_seed_article(
          category: hr, author: author, status: 'published',
          title: 'SOP Pengajuan Cuti Tahunan',
          tags: %w[SOP Cuti],
          content: <<~MD
            # SOP Pengajuan Cuti Tahunan

            ## Ringkasan

            SOP ini mengatur mekanisme pengajuan, verifikasi, dan persetujuan cuti tahunan karyawan agar tercatat konsisten di seluruh divisi.

            ## Ketentuan Umum

            - Jatah cuti tahunan 12 hari kerja per tahun kalender
            - Pengajuan minimal 3 hari kerja sebelum tanggal cuti
            - Sisa cuti dapat dibawa maksimal 6 hari ke tahun berikutnya

            ## Langkah Pengajuan

            1. Buka modul Kehadiran > Pengajuan Cuti
            2. Pilih rentang tanggal dan jenis cuti "Tahunan"
            3. Sistem menampilkan sisa saldo cuti secara otomatis
            4. Kirim pengajuan - status berubah menjadi "Menunggu Approval"

            ## Eskalasi dan Approval

            | Level | Penyetuju | SLA |
            |---|---|---|
            | 1 | Atasan langsung | 1 hari kerja |
            | 2 | HR Business Partner | 1 hari kerja |
          MD
        )

        kb_seed_article(
          category: hr, author: author, status: 'published',
          title: 'Kebijakan Work From Home (WFH)',
          tags: %w[Kebijakan],
          content: <<~MD
            # Kebijakan Work From Home (WFH)

            ## Ringkasan

            Kebijakan ini mengatur ketentuan kerja dari rumah (WFH) bagi karyawan tetap dan kontrak.

            ## Ketentuan

            - Maksimal 2 hari WFH per minggu, disetujui oleh atasan langsung
            - Karyawan wajib dapat dihubungi selama jam kerja normal
            - Kehadiran tetap dicatat melalui sistem absensi digital

            ## Pengecualian

            Posisi yang mengharuskan kehadiran fisik penuh (misalnya resepsionis, staf gudang) tidak berlaku untuk kebijakan ini kecuali ada persetujuan khusus dari HR.
          MD
        )

        kb_seed_article(
          category: hr, author: author, status: 'draft',
          title: 'Template Formulir Penilaian Kinerja Tahunan',
          tags: %w[Template Kinerja],
          content: <<~MD
            # Template Formulir Penilaian Kinerja Tahunan

            > Draft - masih menunggu review dari tim HR sebelum dipublikasikan.

            ## Bagian A - Identitas Karyawan

            - Nama:
            - Jabatan:
            - Departemen:
            - Periode Penilaian:

            ## Bagian B - Aspek Penilaian

            1. Pencapaian target kerja
            2. Kualitas hasil kerja
            3. Kolaborasi tim
            4. Inisiatif dan kepemimpinan

            ## Bagian C - Rencana Pengembangan

            - Kekuatan utama:
            - Area yang perlu ditingkatkan:
            - Rencana pelatihan/mentoring:
          MD
        )

        puts "Category: PMO (##{pmo.id})"
        kb_seed_article(
          category: pmo, author: author, status: 'published',
          title: 'Panduan Metodologi Manajemen Proyek',
          tags: %w[Panduan Metodologi],
          content: <<~MD
            # Panduan Metodologi Manajemen Proyek

            ## Ringkasan

            Panduan ini menjelaskan metodologi standar yang digunakan PMO dalam mengelola proyek internal maupun proyek klien.

            ## Fase Proyek

            1. Inisiasi - definisi ruang lingkup dan charter proyek
            2. Perencanaan - jadwal, anggaran, dan alokasi sumber daya
            3. Eksekusi - implementasi sesuai rencana
            4. Monitoring and Controlling - pelacakan progres dan risiko
            5. Penutupan - serah terima dan evaluasi akhir

            ## Kerangka Kerja yang Digunakan

            - Waterfall untuk proyek dengan ruang lingkup tetap
            - Agile/Scrum untuk proyek pengembangan produk iteratif

            ## Referensi

            - SOP Pelaporan Status Proyek Mingguan
            - Template RACI Matrix
          MD
        )

        kb_seed_article(
          category: pmo, author: author, status: 'published',
          title: 'SOP Pelaporan Status Proyek Mingguan',
          tags: %w[SOP Pelaporan],
          content: <<~MD
            # SOP Pelaporan Status Proyek Mingguan

            ## Ringkasan

            Setiap project manager wajib mengirimkan laporan status proyek setiap minggu kepada PMO.

            ## Ketentuan

            - Laporan dikirim setiap Jumat sebelum pukul 17.00
            - Format laporan mengikuti template standar PMO
            - Status proyek: On Track, At Risk, atau Delayed

            ## Isi Laporan

            1. Ringkasan progres minggu ini
            2. Milestone yang tercapai
            3. Risiko dan isu yang teridentifikasi
            4. Rencana tindak lanjut minggu depan

            ## Eskalasi

            Proyek dengan status "At Risk" selama 2 minggu berturut-turut wajib dieskalasi ke Steering Committee.
          MD
        )

        kb_seed_article(
          category: pmo, author: author, status: 'published',
          title: 'Template RACI Matrix',
          tags: %w[Template],
          content: <<~MD
            # Template RACI Matrix

            ## Ringkasan

            Template ini digunakan untuk mendefinisikan peran dan tanggung jawab pada setiap aktivitas proyek.

            ## Definisi

            - **R**esponsible - pihak yang mengerjakan aktivitas
            - **A**ccountable - pihak yang bertanggung jawab penuh atas hasil
            - **C**onsulted - pihak yang dimintai masukan
            - **I**nformed - pihak yang perlu diberi informasi

            ## Contoh Tabel RACI

            | Aktivitas | Project Manager | Tim Teknis | Sponsor | Stakeholder |
            |---|---|---|---|---|
            | Perencanaan proyek | A | C | I | I |
            | Pengembangan | I | R | I | I |
            | Review milestone | A | C | A | C |
            | Persetujuan anggaran | C | I | A | I |
          MD
        )

        kb_seed_article(
          category: pmo, author: author, status: 'draft',
          title: 'Kebijakan Eskalasi Risiko Proyek',
          tags: %w[Kebijakan Risiko],
          content: <<~MD
            # Kebijakan Eskalasi Risiko Proyek

            > Draft - menunggu finalisasi threshold eskalasi dari manajemen.

            ## Ringkasan

            Kebijakan ini mengatur kapan dan bagaimana risiko proyek harus dieskalasi ke level manajemen yang lebih tinggi.

            ## Level Risiko

            1. Rendah - ditangani oleh project manager
            2. Sedang - dilaporkan ke PMO Lead
            3. Tinggi - dieskalasi ke Steering Committee
          MD
        )

        puts 'Done.'
      end

      def kb_seed_category(name, description)
        category = KbCategory.find_or_initialize_by(name: name)
        was_new = category.new_record?
        category.description = description if was_new
        category.save!
        puts(was_new ? "  + category created: #{name}" : "  = category exists: #{name}")
        category
      end

      def kb_seed_tag(name)
        KbTag.find_or_create_by!(name: name)
      end

      def kb_seed_article(category:, author:, status:, title:, tags:, content:)
        if KbArticle.exists?(kb_category_id: category.id, title: title)
          puts "  - skip (exists): #{title}"
          return
        end

        article = KbArticle.new(kb_category: category, title: title, content: content.strip, status: status)
        article.author = author
        article.updated_by = author
        article.save!
        article.tag_ids = tags.map { |t| kb_seed_tag(t).id }
        puts "  + article created: #{title} [#{status}]"
        article
      end
    end
  end
end
