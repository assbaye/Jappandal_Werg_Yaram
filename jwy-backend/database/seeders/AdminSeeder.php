<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class AdminSeeder extends Seeder
{
    public function run(): void
    {
        $admin = User::firstOrCreate(
            ['email' => 'admin@jwy.sn'],
            [
                'password'  => Hash::make('Admin@JWY2024'),
                'telephone' => '+221777000001',
                'role'      => 'admin',
                'est_actif' => true,
            ]
        );

        $admin->assignRole('admin');

        $this->command->info("Admin créé : admin@jwy.sn / Admin@JWY2024");
    }
}
