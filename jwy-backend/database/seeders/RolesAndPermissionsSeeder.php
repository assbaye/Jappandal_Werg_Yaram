<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Role;
use Spatie\Permission\Models\Permission;

class RolesAndPermissionsSeeder extends Seeder
{
    public function run(): void
    {
        // Reset cached roles and permissions
        app()[\Spatie\Permission\PermissionRegistrar::class]->forgetCachedPermissions();

        // Permissions
        $permissions = [
            // Consultations
            'create_consultation',
            'view_consultation',
            'update_consultation',
            'cancel_consultation',

            // Prescriptions
            'create_prescription',
            'view_prescription',

            // Dossiers médicaux
            'view_dossier_medical',
            'update_dossier_medical',

            // Pharmacie
            'manage_stock',
            'view_commandes',
            'process_commande',

            // Administration
            'manage_users',
            'manage_medecins',
            'view_stats',
            'send_alerte_sante',

            // Paiements
            'view_paiements',
            'refund_paiement',
        ];

        foreach ($permissions as $permission) {
            Permission::firstOrCreate(['name' => $permission, 'guard_name' => 'api']);
        }

        // Rôles
        $patient = Role::firstOrCreate(['name' => 'patient', 'guard_name' => 'api']);
        $patient->givePermissionTo([
            'create_consultation',
            'view_consultation',
            'cancel_consultation',
            'view_prescription',
            'view_dossier_medical',
            'view_paiements',
        ]);

        $medecin = Role::firstOrCreate(['name' => 'medecin', 'guard_name' => 'api']);
        $medecin->givePermissionTo([
            'view_consultation',
            'update_consultation',
            'create_prescription',
            'view_prescription',
            'view_dossier_medical',
            'update_dossier_medical',
            'view_paiements',
        ]);

        $pharmacien = Role::firstOrCreate(['name' => 'pharmacien', 'guard_name' => 'api']);
        $pharmacien->givePermissionTo([
            'manage_stock',
            'view_commandes',
            'process_commande',
            'view_paiements',
        ]);

        $admin = Role::firstOrCreate(['name' => 'admin', 'guard_name' => 'api']);
        $admin->givePermissionTo(Permission::all());

        $this->command->info('Roles and permissions created successfully.');
    }
}
