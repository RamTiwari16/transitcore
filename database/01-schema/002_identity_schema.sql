/*
  Purpose:      Identity domain — Users, Roles, UserRoles, Permissions,
                RolePermissions, UserBranches, RefreshTokens.
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: 001_lookup_core.sql (Regions, Branches, Designations,
                WorkingDesignations)
*/
SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'identity')
    EXEC('CREATE SCHEMA identity');
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('identity.Roles') AND type = 'U')
BEGIN
    CREATE TABLE identity.Roles
    (
        Id          INT IDENTITY(1,1) NOT NULL,
        Name        NVARCHAR(100)     NOT NULL,
        CreatedAt   DATETIME2(3)      NOT NULL CONSTRAINT DF_Roles_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy   NVARCHAR(256)     NULL,
        ModifiedAt  DATETIME2(3)      NULL,
        ModifiedBy  NVARCHAR(256)     NULL,
        IsDeleted   BIT               NOT NULL CONSTRAINT DF_Roles_IsDeleted DEFAULT 0,
        CONSTRAINT PK_Roles PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_Roles_Name UNIQUE (Name)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('identity.Permissions') AND type = 'U')
BEGIN
    CREATE TABLE identity.Permissions
    (
        Id          INT IDENTITY(1,1) NOT NULL,
        Name        NVARCHAR(150)     NOT NULL,
        CreatedAt   DATETIME2(3)      NOT NULL CONSTRAINT DF_Permissions_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy   NVARCHAR(256)     NULL,
        ModifiedAt  DATETIME2(3)      NULL,
        ModifiedBy  NVARCHAR(256)     NULL,
        IsDeleted   BIT               NOT NULL CONSTRAINT DF_Permissions_IsDeleted DEFAULT 0,
        CONSTRAINT PK_Permissions PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_Permissions_Name UNIQUE (Name)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('identity.RolePermissions') AND type = 'U')
BEGIN
    CREATE TABLE identity.RolePermissions
    (
        RoleId       INT NOT NULL,
        PermissionId INT NOT NULL,
        CONSTRAINT PK_RolePermissions PRIMARY KEY CLUSTERED (RoleId, PermissionId),
        CONSTRAINT FK_RolePermissions_Roles FOREIGN KEY (RoleId) REFERENCES identity.Roles (Id) ON DELETE CASCADE,
        CONSTRAINT FK_RolePermissions_Permissions FOREIGN KEY (PermissionId) REFERENCES identity.Permissions (Id) ON DELETE CASCADE
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('identity.Users') AND type = 'U')
BEGIN
    CREATE TABLE identity.Users
    (
        Id                   INT IDENTITY(1,1) NOT NULL,
        Email                NVARCHAR(256)     NOT NULL,
        PasswordHash         NVARCHAR(256)     NOT NULL,
        PasswordSalt         NVARCHAR(256)     NOT NULL,
        DisplayName          NVARCHAR(200)     NOT NULL,
        PhoneNo              NVARCHAR(30)      NULL,
        EmpCode              NVARCHAR(50)      NULL,
        DesignationId        INT               NULL,
        WorkingDesignationId INT               NULL,
        RegionId             INT               NULL,
        PunchLocation        NVARCHAR(200)     NULL,
        Shift                NVARCHAR(50)      NULL,
        Company              NVARCHAR(200)     NULL,
        IsActive             BIT               NOT NULL CONSTRAINT DF_Users_IsActive DEFAULT 1,
        CreatedAt            DATETIME2(3)      NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy            NVARCHAR(256)     NULL,
        ModifiedAt           DATETIME2(3)      NULL,
        ModifiedBy           NVARCHAR(256)     NULL,
        IsDeleted            BIT               NOT NULL CONSTRAINT DF_Users_IsDeleted DEFAULT 0,
        CONSTRAINT PK_Users PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_Users_Email UNIQUE (Email),
        CONSTRAINT FK_Users_Designations FOREIGN KEY (DesignationId) REFERENCES lookup.Designations (Id) ON DELETE NO ACTION,
        CONSTRAINT FK_Users_WorkingDesignations FOREIGN KEY (WorkingDesignationId) REFERENCES lookup.WorkingDesignations (Id) ON DELETE NO ACTION,
        CONSTRAINT FK_Users_Regions FOREIGN KEY (RegionId) REFERENCES lookup.Regions (Id) ON DELETE NO ACTION
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Users_DesignationId' AND object_id = OBJECT_ID('identity.Users'))
    CREATE NONCLUSTERED INDEX IX_Users_DesignationId ON identity.Users (DesignationId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Users_WorkingDesignationId' AND object_id = OBJECT_ID('identity.Users'))
    CREATE NONCLUSTERED INDEX IX_Users_WorkingDesignationId ON identity.Users (WorkingDesignationId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Users_RegionId' AND object_id = OBJECT_ID('identity.Users'))
    CREATE NONCLUSTERED INDEX IX_Users_RegionId ON identity.Users (RegionId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('identity.UserRoles') AND type = 'U')
BEGIN
    CREATE TABLE identity.UserRoles
    (
        UserId INT NOT NULL,
        RoleId INT NOT NULL,
        CONSTRAINT PK_UserRoles PRIMARY KEY CLUSTERED (UserId, RoleId),
        CONSTRAINT FK_UserRoles_Users FOREIGN KEY (UserId) REFERENCES identity.Users (Id) ON DELETE CASCADE,
        CONSTRAINT FK_UserRoles_Roles FOREIGN KEY (RoleId) REFERENCES identity.Roles (Id) ON DELETE CASCADE
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_UserRoles_RoleId' AND object_id = OBJECT_ID('identity.UserRoles'))
    CREATE NONCLUSTERED INDEX IX_UserRoles_RoleId ON identity.UserRoles (RoleId);
GO

-- Replaces the legacy comma-separated BranchIds string with a proper join table.
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('identity.UserBranches') AND type = 'U')
BEGIN
    CREATE TABLE identity.UserBranches
    (
        UserId   INT NOT NULL,
        BranchId INT NOT NULL,
        CONSTRAINT PK_UserBranches PRIMARY KEY CLUSTERED (UserId, BranchId),
        CONSTRAINT FK_UserBranches_Users FOREIGN KEY (UserId) REFERENCES identity.Users (Id) ON DELETE CASCADE,
        CONSTRAINT FK_UserBranches_Branches FOREIGN KEY (BranchId) REFERENCES lookup.Branches (Id) ON DELETE NO ACTION
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_UserBranches_BranchId' AND object_id = OBJECT_ID('identity.UserBranches'))
    CREATE NONCLUSTERED INDEX IX_UserBranches_BranchId ON identity.UserBranches (BranchId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('identity.RefreshTokens') AND type = 'U')
BEGIN
    CREATE TABLE identity.RefreshTokens
    (
        Id                     INT IDENTITY(1,1) NOT NULL,
        UserId                 INT               NOT NULL,
        TokenHash              NVARCHAR(256)     NOT NULL,
        ExpiresAt              DATETIME2(3)      NOT NULL,
        CreatedAt              DATETIME2(3)      NOT NULL CONSTRAINT DF_RefreshTokens_CreatedAt DEFAULT SYSUTCDATETIME(),
        RevokedAt              DATETIME2(3)      NULL,
        ReplacedByTokenHash    NVARCHAR(256)     NULL,
        CONSTRAINT PK_RefreshTokens PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_RefreshTokens_Users FOREIGN KEY (UserId) REFERENCES identity.Users (Id) ON DELETE CASCADE,
        CONSTRAINT UQ_RefreshTokens_TokenHash UNIQUE (TokenHash)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_RefreshTokens_UserId' AND object_id = OBJECT_ID('identity.RefreshTokens'))
    CREATE NONCLUSTERED INDEX IX_RefreshTokens_UserId ON identity.RefreshTokens (UserId);
GO
